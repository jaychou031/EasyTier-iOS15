#ifndef EasyTierNetworkExtension_Bridging_Header_h
#define EasyTierNetworkExtension_Bridging_Header_h

#include <TargetConditionals.h>

#if TARGET_OS_OSX

#include <sys/ioccom.h>
#include <sys/kern_control.h>

// The SDK's _IOWR expression contains sizeof(struct ctl_info), which Swift's
// Clang importer cannot expose. Replace it with the equivalent Darwin value.
#ifdef CTLIOCGINFO
#undef CTLIOCGINFO
#endif
#define CTLIOCGINFO 0xc0644e03UL

#else

#include "kern_control.h"

#endif

#include "easytier_ios.h"

#endif
