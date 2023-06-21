//go:build asan

package main

/*
#if defined(__has_feature)
#if __has_feature(leak_sanitizer)
#define USE_LEAK_SANITIZER 1
#endif
#endif

#if defined(USE_LEAK_SANITIZER)
#include <sanitizer/lsan_interface.h>
#else
#error "Leak sanitizer is not correctly configured"
#endif
*/
import "C"
import (
	"runtime"
	_ "runtime/asan"
)

func doLeakSanitizerCheck() {
	runtime.GC()
	C.__lsan_do_leak_check()
}
