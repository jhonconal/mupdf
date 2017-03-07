//
//  NTKOSignFile_espfile.m
//  MuPDF
//
//  Created by 曾亮 on 2017/2/27.
//  Copyright © 2017年 Artifex Software, Inc. All rights reserved.
//

#import "NTKODsSvrSignFile.h"
#include "mupdf/z/ntko_esp.h"


@implementation NTKODsSvrSignFile{
	// fz_pixmap *_pixmap;
	ntko_server_espinfo *_svrespinfo;
}

- (BOOL)open:(NSString *)password {
	if(![self download]) return NO;
	
	NTKOEspParser *parser = NULL;
	bool isok = false;
	// fz_image *image = NULL;
	fz_buffer *imgbuf = NULL;
	fz_try(ctx) {
		parser = NTKOEspParser::create(ctx);
		isok = parser->open(_svrespinfo->data, (char*)[password UTF8String]);
		if(isok) {
			[self resetAttributes];
			const NTKOEspHeader *header = parser->getHeader();
			unsigned char *imgbytes = NULL;
			int size = 0;
			_name = [[NSString stringWithUTF8String:header->signname]retain];
			_sn = [[NSString stringWithUTF8String:header->signSN]retain];
			_unid = [[[NSUUID UUID] UUIDString]retain];
			_user = [[NSString stringWithUTF8String:header->signuser]retain];
			_signer = [getLoginuser() retain];
			imgbuf = parser->getImagedata();
			
			size = (int)fz_buffer_get_data(ctx, imgbuf, &imgbytes);
			_imagedata = [[NSData alloc] initWithBytes:imgbytes length:size];
			// image = parser->getImage();
			// _pixmap  = fz_get_pixmap_from_image(ctx, image, NULL, NULL, 0, 0);
		}
	}
	fz_always(ctx) {
		if(imgbuf) fz_drop_buffer(ctx, imgbuf);
		// if(image) fz_drop_image(ctx, image);
		if(parser) delete parser;
	}
	fz_catch(ctx) {
		isok = false;
		NSLog(@"open esp failed:%s", fz_caught_message(ctx));
	}
	return isok;
}

- (BOOL) download {
	if (_svrespinfo->data) return YES;
	
	bool isok = false;
	fz_try(ctx) {
		if(!_svrespinfo->data)
			isok = download_server_esp(_svrespinfo);
	}
	fz_catch(ctx)
		NSLog(@"download esp failed:%s", fz_caught_message(ctx));
		
	return isok?YES:NO;
}

- (NSData*) data {
	return nil;
}

- (instancetype) initWithSvrEspInfo:(ntko_server_espinfo *)espinfo
{
	self = [super init];
	if(self) {
		_svrespinfo = ntko_keep_server_espinfo(ctx, espinfo);
		_name = [[NSString stringWithUTF8String: espinfo->signname]retain];
		_user = [[NSString stringWithUTF8String:espinfo->signuser]retain];
		_title = [_name retain];
		_describe = [_user retain];
	}
	return self;
}

- (UIImage*) image {
#if 1
	if(!_imagedata) return nil;
	return [UIImage imageWithData:_imagedata];
#else
	UIImage *image_ui = nil;
	
	CGDataProviderRef imagedata = CreateWrappedPixmap(_pixmap);
	image_ui = newImageWithPixmap(_pixmap, imagedata, 1.0f);
	CGDataProviderRelease(imagedata);
	return image_ui;
#endif

}

- (void) resetAttributes {
	if(_name) {[_name release]; _name=nil;}
	if(_sn) {[_sn release]; _sn=nil;}
	if(_unid) {[_unid release]; _unid=nil;}
	if(_user) {[_user release]; _user=nil;}
	if(_signer) {[_signer release]; _signer=nil;}
	if(_title) {[_title release]; _title=nil;}
	if(_describe) {[_describe release]; _describe=nil;}
	if(_imagedata) {[_imagedata release]; _imagedata = nil;}
}

- (void)dealloc {
	[self resetAttributes];
	if(_svrespinfo) ntko_drop_server_espinfo(ctx, _svrespinfo);
	[super dealloc];
}

#ifdef SVR_SIGN
+ (NSArray<NTKODsSvrSignFile*>*) svrEsplist {
	if(!_ssCtx || !_ssCtx->logined) {
		NSLog(@"please login first!");
		return nil;
	}
	z_list *esplist = NULL;
	NSMutableArray *array = nil;
	fz_try(ctx) {
		// ntko_server_espinfo *espinfo = NULL;
		NTKODsSvrSignFile *ds = nil;
		z_list_node *node = NULL;
		
		esplist = ntko_http_get_esplist(ctx, &_ssCtx->svrinfo, &_ssCtx->rights,
			&_ssCtx->options, &_ssCtx->status);
		
		node = esplist->first;
		if(node)
			array = [[NSMutableArray alloc]initWithCapacity:2];
		while(node) {
			ds = [[NTKODsSvrSignFile alloc]initWithSvrEspInfo:(ntko_server_espinfo*)node->data];
			[array addObject:ds];
			
			node = node->n;
		}
	}
	fz_always(ctx) {
		if(esplist) z_list_free(ctx, esplist);
	}
	fz_catch(ctx)
		NSLog(@"%s", fz_caught_message(ctx));
	
	return array;
}

#else
+ (NSArray*) svrEsplist {
	NSLog(@"not defined SVR_SIGN macro");
	return nil;
}
#endif // #ifdef SVR_SIGN

@end
