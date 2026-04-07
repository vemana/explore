#include "tracer.h"
#include <iostream>

using Tracer = vecu::trace::Tracer;

void testAllEvents() {
  Tracer tracer;
  tracer.trace("First event");
 
  long long j = 0; 
  for(int i=0;i<100'000'000;i++) {
    j += i;
  }
  tracer.trace(std::format("Second event [{:^10}] [{}]", 123, j));

  tracer.printAll(std::cout);
}

int main() {
  testAllEvents();
  return 0;
}
