/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * Created by james <https://github.com/mystcolor> on 9/28/11.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDecoder.h"
#import "libraw.h"

@implementation UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image {
    if (image.images) {
        // Do not decode animated images
        return image;
    }

    CGImageRef imageRef = image.CGImage;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    CGRect imageRect = (CGRect){.origin = CGPointZero, .size = imageSize};

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);

    int infoMask = (bitmapInfo & kCGBitmapAlphaInfoMask);
    BOOL anyNonAlpha = (infoMask == kCGImageAlphaNone ||
            infoMask == kCGImageAlphaNoneSkipFirst ||
            infoMask == kCGImageAlphaNoneSkipLast);

    // CGBitmapContextCreate doesn't support kCGImageAlphaNone with RGB.
    // https://developer.apple.com/library/mac/#qa/qa1037/_index.html
    if (infoMask == kCGImageAlphaNone && CGColorSpaceGetNumberOfComponents(colorSpace) > 1) {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;

        // Set noneSkipFirst.
        bitmapInfo |= kCGImageAlphaNoneSkipFirst;
    }
            // Some PNGs tell us they have alpha but only 3 components. Odd.
    else if (!anyNonAlpha && CGColorSpaceGetNumberOfComponents(colorSpace) == 3) {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;
        bitmapInfo |= kCGImageAlphaPremultipliedFirst;
    }

    // It calculates the bytes-per-row based on the bitsPerComponent and width arguments.
    CGContextRef context = CGBitmapContextCreate(NULL,
            imageSize.width,
            imageSize.height,
            CGImageGetBitsPerComponent(imageRef),
            0,
            colorSpace,
            bitmapInfo);
    CGColorSpaceRelease(colorSpace);

    // If failed, return undecompressed image
    if (!context) return image;

    CGContextDrawImage(context, imageRect, imageRef);
    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);

    CGContextRelease(context);

    UIImage *decompressedImage = [UIImage imageWithCGImage:decompressedImageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(decompressedImageRef);
    return decompressedImage;
}

+ (UIImage *)decodedImageWithRawData:(NSData *)rawData
{
    int ret;
    UIImage* decompressedImage = nil;
    
    libraw_data_t *raw_data = libraw_init(0);
    
    // (-w) Use the white balance specified by the camera
    raw_data->params.use_camera_wb = 1;
    // (-q 0) linear interpolation
    raw_data->params.user_qual = 0;
    // (-6) 16-bit or 8-bit
    raw_data->params.output_bps = 8;
    // (-h) half-size color image
    raw_data->params.half_size = 1;
    
    // Load raw data in libRaw
    NSUInteger len = [rawData length];
    Byte *byteData = (Byte *)malloc(len);
    memcpy(byteData, [rawData bytes], len);
    libraw_open_buffer(raw_data, byteData, len);
    
    // Unpack raw data
    ret = libraw_unpack(raw_data);
    
    // Free memory
    free(byteData);
    
    if (ret == LIBRAW_SUCCESS)
    {
        // process data (... most consuming task ...)
        ret = libraw_dcraw_process(raw_data);
        if ((ret == LIBRAW_SUCCESS) || (!LIBRAW_FATAL_ERROR(ret)))
        {
            // retrieve processed image
            libraw_processed_image_t *processedImage = libraw_dcraw_make_mem_image(raw_data, NULL);
            
            if ((processedImage->type == LIBRAW_IMAGE_BITMAP) && (processedImage->colors == 3))
            {
                int count = 0;
                Byte *bufptr;
                void *data = NULL;
                Byte *dataptr;
                unsigned int height = processedImage->height;
                unsigned int width = processedImage->width;
                
                // create the bitmap context
                const size_t BitsPerComponent = processedImage->bits;
                // As CGBitmapContextCreate is not supporting RGB context (only ARGB/RGBA), we add 1 to have 4 components(ARGB) instead of 3 (RGB)
                const size_t BytesPerRow = ((BitsPerComponent * width) / 8) * (processedImage->colors + 1); // +1 to add alpha part
                
                // create the ARGB image
                data = malloc(width * height * (sizeof(UInt32)));
                
                if (data)
                {
                    dataptr = data;
                    bufptr = processedImage->data;
                    
                    for (count = width * height; count > 0; --count)
                    {
                        // No need to set Alpha as we are ignoring it in CGBitmapContextCreate
                        //                      *dataptr = 0xFF; // Alpha
                        *(dataptr+1) = bufptr[0]; // Red
                        *(dataptr+2) = bufptr[1]; // Green
                        *(dataptr+3) = bufptr[2]; // Blue
                        dataptr += 4;
                        bufptr += 3;
                    }
                    
                    // free raw_data
                    libraw_recycle(raw_data);
                    
                    // Free libRaw processed Image
                    libraw_dcraw_clear_mem(processedImage);
                    
                    // create CGImage
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGContextRef context = CGBitmapContextCreate(data,
                                                                 width,
                                                                 height,
                                                                 BitsPerComponent,
                                                                 BytesPerRow,
                                                                 colorSpace,
                                                                 kCGImageAlphaNoneSkipFirst);
                    CGColorSpaceRelease(colorSpace);
                    
                    CGImageRef imageRef = CGBitmapContextCreateImage(context);
                    
                    free(data);
                    
                    CGContextRelease(context);
                    
                    decompressedImage = [UIImage imageWithCGImage:imageRef];
                    
                    // free the memory
                    CGImageRelease(imageRef);
                }
                else
                {
                    // free raw_data
                    libraw_recycle(raw_data);
                    
                    // Free libRaw processed Image
                    libraw_dcraw_clear_mem(processedImage);
                }
            }
            else
            {
                NSLog(@"processedImage incorrect : type = %d colors = %d",processedImage->type,processedImage->colors);
                // free the memory
                libraw_dcraw_clear_mem(processedImage);
            }
        }
        else
        {
            NSLog(@"libraw_dcraw_process failed : %d",ret);
            // free raw_data
            libraw_recycle(raw_data);
        }
    }
    else
    {
        NSLog(@"libraw_unpack failed : %d",ret);
        // free raw_data
        libraw_recycle(raw_data);
    }
    
    return decompressedImage;
}

@end
