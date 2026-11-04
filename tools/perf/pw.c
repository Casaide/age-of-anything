// Average watts per IOReport "Energy Model" channel over <seconds>.
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
typedef CFDictionaryRef (*chans_t)(CFStringRef, CFStringRef, uint64_t, uint64_t, uint64_t);
typedef void *(*sub_t)(void *, CFMutableDictionaryRef, CFMutableDictionaryRef *, uint64_t, CFTypeRef);
typedef CFDictionaryRef (*samp_t)(void *, CFMutableDictionaryRef, CFTypeRef);
typedef CFDictionaryRef (*delta_t)(CFDictionaryRef, CFDictionaryRef, CFTypeRef);
typedef CFStringRef (*str_t)(CFDictionaryRef);
typedef int64_t (*val_t)(CFDictionaryRef, int);
static double per_j(CFStringRef u){ char b[16]=""; CFStringGetCString(u,b,16,kCFStringEncodingUTF8);
    if(!strcmp(b,"mJ"))return 1e-3; if(!strcmp(b,"uJ"))return 1e-6; if(!strcmp(b,"nJ"))return 1e-9; return 1; }
int main(int c,char**v){ int secs=c>1?atoi(v[1]):10;
    void*h=dlopen("/usr/lib/libIOReport.dylib",RTLD_NOW); if(!h){puts(dlerror());return 1;}
    chans_t chans=dlsym(h,"IOReportCopyChannelsInGroup"); sub_t sub=dlsym(h,"IOReportCreateSubscription");
    samp_t samp=dlsym(h,"IOReportCreateSamples"); delta_t delta=dlsym(h,"IOReportCreateSamplesDelta");
    str_t name=dlsym(h,"IOReportChannelGetChannelName"), unit=dlsym(h,"IOReportChannelGetUnitLabel"); val_t val=dlsym(h,"IOReportSimpleGetIntegerValue");
    CFDictionaryRef ch=chans(CFSTR("Energy Model"),NULL,0,0,0);
    CFMutableDictionaryRef m=CFDictionaryCreateMutableCopy(NULL,0,ch),out=NULL;
    void*s=sub(NULL,m,&out,0,NULL);
    CFDictionaryRef a=samp(s,m,NULL); sleep(secs); CFDictionaryRef b=samp(s,m,NULL);
    CFDictionaryRef d=delta(a,b,NULL);
    CFArrayRef arr=CFDictionaryGetValue(d,CFSTR("IOReportChannels"));
    double cpu=0,gpu=0,dram=0,ane=0;
    for(CFIndex i=0;i<CFArrayGetCount(arr);i++){ CFDictionaryRef it=CFArrayGetValueAtIndex(arr,i);
        char n[64]=""; CFStringGetCString(name(it),n,64,kCFStringEncodingUTF8);
        double w=val(it,0)*per_j(unit(it))/secs;
        if(c>2) printf("%-28s %7.3f W\n",n,w);
        if(!strcmp(n,"GPU Energy")) gpu=w;
        else if(strstr(n,"CPU Energy")) cpu+=w;
        else if(!strncmp(n,"DRAM",4)) dram+=w;
    }
    printf("cpu %.2f W  gpu %.2f W  dram %.2f W\n",cpu,gpu,dram); return 0; }
