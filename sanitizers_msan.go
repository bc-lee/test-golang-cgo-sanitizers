//go:build msan

package main

import (
	"runtime"
	_ "runtime/msan"
)

func doLeakSanitizerCheck() {
	runtime.GC()
}
