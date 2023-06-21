//go:build !asan && !msan

package main

import "runtime"

func doLeakSanitizerCheck() {
	runtime.GC()
}
