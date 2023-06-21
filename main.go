package main

/*
#include <stdlib.h>

extern int foo(const char*);
*/
// #cgo CPPFLAGS: -I${SRCDIR}/native
// #cgo CFLAGS: -std=c11 -Wall
// #cgo LDFLAGS: -Lnative -lfoo
import "C"
import (
	"time"
	"fmt"
	"unsafe"
)

func main() {
	defer doLeakSanitizerCheck()
	currentTime := time.Now()
	currentTimeStr := currentTime.Format("2006-01-02 15:04:05")
	cStr := C.CString(currentTimeStr)
	defer C.free(unsafe.Pointer(cStr))
	result := C.foo(cStr)
	fmt.Printf("Result: %d\n", result)
}
