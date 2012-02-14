//
//  NoSleepInterface.cpp
//  nosleep
//
//  Created by Pavel Prokofiev on 4/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NoSleepInterface.h"

#import <Foundation/Foundation.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/IOKitKeys.h>
#import <Kernel/mach/mach_port.h>
#import <ApplicationServices/ApplicationServices.h>

#import <IOKit/OSMessageNotification.h>

#import <GlobalConstants.h>

NoSleepInterestNotification NoSleep_ReceiveStateChanged(NoSleepInterfaceService service,
                                                        IOServiceInterestCallback callback,
                                                        void *refCon)
{
    io_object_t notifyObj;
    mach_port_t masterPort;
    kern_return_t kr;
    CFRunLoopSourceRef runLoopSource;
    
    IONotificationPortRef notifyPort;
    
    kr = IOMasterPort (MACH_PORT_NULL, &masterPort);
    if (!kr && masterPort) {
        notifyPort = IONotificationPortCreate (masterPort);
        runLoopSource = IONotificationPortGetRunLoopSource (notifyPort);
        
        //CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop],
        //                   runLoopSource,
        //                   kCFRunLoopDefaultMode);
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           runLoopSource,
                           kCFRunLoopDefaultMode);

        kr = IOServiceAddInterestNotification(notifyPort,
                                              service,
                                              kIOGeneralInterest,
                                              callback,
                                              refCon, 
                                              &notifyObj);
        
        mach_port_deallocate (mach_task_self(), masterPort);
        
        if (kr != KERN_SUCCESS)
        {
            fprintf(stderr, "IOServiceAddInterestNotification returned 0x%08x\n", kr);
            return 0;
        }
    }
    
    return (NoSleepInterfaceConnect)notifyObj;
}

void NoSleep_ReleaseStateChanged(NoSleepInterestNotification notifyObj)
{
    IOObjectRelease(notifyObj);
}

bool NoSleep_InterfaceCreate(NoSleepInterfaceService *service, NoSleepInterfaceConnect *connect)
{
    kern_return_t	kernResult; 
    io_service_t	_service;
    io_iterator_t 	iterator;
	bool			driverFound = false;
    
    kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kNoSleepDriverClassName), &iterator);

    if (kernResult != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceGetMatchingServices returned 0x%08x\n", kernResult);
        return false;
    }
    
    while ((_service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
		driverFound = true;
		printf("Found a device of class "kNoSleepDriverClassName"\n");
        break;
	}
    
    IOObjectRelease(iterator);
    
    if(driverFound)
    {
        kernResult = IOServiceOpen(_service, mach_task_self(), 0, connect);

        if (kernResult != KERN_SUCCESS) {
            fprintf(stderr, "IOServiceOpen returned 0x%08x\n", kernResult);
            return false;
        }
        
        *service = _service;
    }
    else
    {
        fprintf(stderr, "Can't found a driver\n");
        return false;
    }
    
    fprintf(stderr, "IOServiceOpen was successful\n");
    return true;
}

bool NoSleep_InterfaceDestroy(NoSleepInterfaceConnect connect)
{
    kern_return_t kernResult = IOServiceClose(connect);
    
    if (kernResult == KERN_SUCCESS) {
        printf("IOServiceClose was successful\n");
        return true;
    }
    else {
	    fprintf(stderr, "IOServiceClose returned 0x%08x\n", kernResult);
        return false;
    }
}

bool NoSleep_GetSleepSuppressionMode(NoSleepInterfaceConnect connect)
{
    uint64_t scalarO_64;
    uint32_t outputCount = 1; 
    
    IOConnectCallScalarMethod(connect,	// an io_connect_t returned from IOServiceOpen().
                              0,                        // selector of the function to be called via the user client.
                              NULL,                     // array of scalar (64-bit) input values.
                              0,						// the number of scalar input values.
                              &scalarO_64,				// array of scalar (64-bit) output values.
                              &outputCount				// pointer to the number of scalar output values.
                              );
    
    return (bool)scalarO_64;
}

bool NoSleep_SetSleepSuppressionMode(NoSleepInterfaceConnect connect, bool mode)
{
    uint64_t scalarI_64;
    uint64_t scalarO_64;
    uint32_t outputCount = 1;
    
    scalarI_64 = (uint64_t)mode;
    
    IOConnectCallScalarMethod(connect,	// an io_connect_t returned from IOServiceOpen().
                              1,                        // selector of the function to be called via the user client.
                              &scalarI_64,              // array of scalar (64-bit) input values.
                              1,						// the number of scalar input values.
                              &scalarO_64,				// array of scalar (64-bit) output values.
                              &outputCount				// pointer to the number of scalar output values.
                              );
    
    return (bool)scalarO_64;
}
