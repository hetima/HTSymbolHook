//
//  main.m
//  HTSymbolHookExample
//
//  Copyright (c) 2013 hetima.
//  MIT License


#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "HTSymbolHook.h"


CFStringRef (*orig__CFStringCreateImmutableFunnel3)();
CFStringRef rep__CFStringCreateImmutableFunnel3(
    CFAllocatorRef alloc, const void *bytes, CFIndex numBytes, CFStringEncoding encoding,
    Boolean possiblyExternalFormat, Boolean tryToReduceUnicode, Boolean hasLengthByte, Boolean hasNullByte, Boolean noCopy,
    CFAllocatorRef contentsDeallocator, UInt32 converterFlags)
{
    printf("(rep__CFStringCreateImmutableFunnel3 called)\n");
    if (!strcmp(bytes, "test")) {
        bytes="replaced!";
        numBytes=strlen(bytes);
    }
    return orig__CFStringCreateImmutableFunnel3(alloc, bytes, numBytes, encoding,
                                                possiblyExternalFormat, tryToReduceUnicode, hasLengthByte, hasNullByte, noCopy,
                                                contentsDeallocator, converterFlags);
}


void checkOverride()
{
    // refer to CFString.c
    // www.opensource.apple.com/source/CF/CF-744.19/CFString.c
    
    printf("---- override test ----\n");
    CFStringRef str;
    
    //create CFString
    str=CFStringCreateWithCString(kCFAllocatorDefault, "test", kCFStringEncodingUTF8);
    printf("test string is \"%s\"\n", CFStringGetCStringPtr(str, kCFStringEncodingUTF8));
    CFRelease(str);

    //now override
    HTSymbolHook* hook=[HTSymbolHook symbolHookWithImageNameSuffix:@"/CoreFoundation"];
    [hook overrideSymbol:@"___CFStringCreateImmutableFunnel3"
                 withPtr:rep__CFStringCreateImmutableFunnel3
           reentryIsland:(void**)&orig__CFStringCreateImmutableFunnel3];
    
    //create again
    str=CFStringCreateWithCString(kCFAllocatorDefault, "test", kCFStringEncodingUTF8);
    printf("test string is \"%s\"\n", CFStringGetCStringPtr(str, kCFStringEncodingUTF8));
    CFRelease(str);
    
}


void checkAddressVersusDlsym()
{
    printf("---- check address versus dlsym ----\n");
    HTSymbolHook* hook=[HTSymbolHook symbolHookWithImageNameSuffix:@"/Foundation"];
    //dlsym not needs _
    void* dlsymPtr=dlsym(RTLD_DEFAULT, "NSClassFromString");
    //HTSymbolHook needs _
    void* htshPtr=[hook symbolPtrWithSymbolName:@"_NSClassFromString"];
    
    printf("dlsym:%p\n", dlsymPtr);
    printf("HTSym:%p\n", htshPtr);
    printf("Result of dlsym and HTSymbolHook is %s.\n", dlsymPtr==htshPtr? "same":"different");
    
    UInt32 i;
    void* ptr;
    NSDate *date;
    NSTimeInterval t;
    
    printf("---- speed test ----\n");
    date = [NSDate date];
    for (i=0; i<1000; i++) {
        ptr=dlsym(RTLD_DEFAULT, "NSClassFromString");
    }
    t=[[NSDate date] timeIntervalSinceDate:date];
    printf("          dlsym:%lf sec\n", t);
    
    
    date = [NSDate date];
    for (i=0; i<1000; i++) {
        ptr=[hook symbolPtrWithSymbolName:@"_NSClassFromString"];
    }
    t=[[NSDate date] timeIntervalSinceDate:date];
    printf("       HTSymbol:%lf sec\n", t);
    
    
    // should check index in advance
    UInt32 correctIndex=[hook indexOfSymbol:@"_NSClassFromString"]; // is 17573 on 10.8.5
    
    UInt32 index=correctIndex-10;
    date = [NSDate date];
    for (i=0; i<1000; i++) {
        ptr=[hook symbolPtrWithSymbolName:@"_NSClassFromString" startOffset:index endOffset:0];
    }
    t=[[NSDate date] timeIntervalSinceDate:date];
    // if hint is correct, faster than dlsym()
    printf("HTSym with hint:%lf sec\n", t);
    
    // no problem when index is larger than target. but slower than no hint.
    index=correctIndex+10;
    date = [NSDate date];
    for (i=0; i<1000; i++) {
        ptr=[hook symbolPtrWithSymbolName:@"_NSClassFromString" startOffset:index endOffset:0];
    }
    t=[[NSDate date] timeIntervalSinceDate:date];
    printf("If hint is over:%lf sec\n", t);

}


int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        checkAddressVersusDlsym();
        checkOverride();

    }
    return 0;
}

