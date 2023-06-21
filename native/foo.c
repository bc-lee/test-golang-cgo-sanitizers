#include <string.h>

__attribute__((visibility("default")))
int foo(const char* str) {
  return strlen(str);
}
