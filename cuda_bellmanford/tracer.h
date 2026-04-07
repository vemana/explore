#include <chrono>
#include <cstdint>
#include <format>
#include <iostream>
#include <vector>

auto epoch = std::chrono::high_resolution_clock::now();

namespace vecu {
namespace trace {

using std::string;
using std::chrono::high_resolution_clock;
using std::chrono::duration_cast;
using std::chrono::duration;
using std::chrono::milliseconds;
using std::chrono::time_point;
using std::vector;

struct EventId {

  time_point<high_resolution_clock> timestamp;

  EventId() : timestamp(high_resolution_clock::now()) {}

  bool operator<(const EventId& that) const {
    return timestamp < that.timestamp;
  }

  int64_t millisFromStart() const {
    return duration_cast<milliseconds>(timestamp - epoch).count();
  }
};

struct Event {

  EventId eventId;
  string message;

  string toString() const {
    return std::format("[{:8}] {}", eventId.millisFromStart(), message);
  }
};

struct Tracer {

  vector<Event> events;
  
  EventId trace(string message, bool eager = false) {
    EventId id;
    Event event = {id, message};
    events.push_back(event);
    if(eager) std::cerr << event.toString() << std::endl;
    return id;
  }

  void printAll(std::ostream& os) {
    for(const auto& event : events) {
      os << event.toString() << std::endl;
    }
  }

};

} // namespace trace
} // namespace vecu
