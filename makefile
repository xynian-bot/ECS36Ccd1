CXX = g++
CPPFLAGS = -Iinclude -Itests/src
CXXFLAGS = -O0 --std=c++20 -Wall -Wextra -g -MMD -MP
COVERAGEFLAGS = --coverage
GTEST_LIBS = -lgtest_main -lgtest -pthread
TESTCOVER_DIR = tests/htmlcov
COVERAGE_INFO_FILE = tests/coverage.info
ANALYSIS_ARGS = --max 256 --iter 1024 2048 4096 8192
DEQUE_NAMES = MaxSizeDeque VariableSizeDeque
DEQUE_OBJS = $(addprefix obj/,$(addsuffix .o,$(DEQUE_NAMES)))
COVERAGE_OBJS = $(addprefix tests/obj/,$(addsuffix .o,$(DEQUE_NAMES)))
TEST_SOURCES = $(wildcard tests/src/*.cpp)
TEST_OBJS = $(patsubst tests/src/%.cpp,tests/obj/%.o,$(TEST_SOURCES))
DIRECTORIES = bin obj tests/bin tests/obj $(TESTCOVER_DIR) tests/htmlconv
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.PHONY: all directories test coverage valgrind analysis clean
# Complete verification: tests and coverage first, then leak checks and timing.
all: coverage
	$(MAKE) analysis
directories: $(DIRECTORIES)
# htmlconv is also created to match the alternate spelling in the specification.
$(DIRECTORIES):
	mkdir -p $@
# Ordinary objects are used for performance measurements.
obj/%.o: src/%.cpp | obj
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
# Coverage objects are separate, so timing does not include instrumentation.
tests/obj/%.o: src/%.cpp | tests/obj
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(COVERAGEFLAGS) -c $< -o $@
tests/obj/%.o: tests/src/%.cpp | tests/obj
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(COVERAGEFLAGS) -pthread -c $< -o $@
tests/bin/testdeque: $(COVERAGE_OBJS) $(TEST_OBJS) | tests/bin
	$(CXX) $(LDFLAGS) $(COVERAGEFLAGS) $^ $(GTEST_LIBS) $(LDLIBS) -o $@
test: tests/bin/testdeque
	./tests/bin/testdeque
coverage: test directories
	@lcov --capture --directory . --output-file $(COVERAGE_INFO_FILE) \
		--ignore-errors inconsistent,source 2> lcov.err; status=$$?; \
		sed '/mismatched end line/d' lcov.err >&2; \
		rm -f lcov.err; exit $$status
	lcov --remove $(COVERAGE_INFO_FILE) '/usr/*' '*/tests/src/*' '*/*.h' \
		--output-file $(COVERAGE_INFO_FILE)
	genhtml $(COVERAGE_INFO_FILE) --output-directory $(TESTCOVER_DIR)
bin/analysis: obj/analysis.o $(DEQUE_OBJS) | bin
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@
# A nonzero Valgrind result stops make and prevents the timing run.
valgrind: bin/analysis
	valgrind --leak-check=full --show-leak-kinds=all \
		--errors-for-leak-kinds=all --error-exitcode=1 \
		./bin/analysis $(ANALYSIS_ARGS)
# One invocation retains all four iteration counts in results.csv.
analysis: valgrind
	./bin/analysis $(ANALYSIS_ARGS)
clean:
	rm -rf bin obj tests/bin tests/obj tests/htmlcov tests/htmlconv
	rm -f $(COVERAGE_INFO_FILE) lcov.err
# Generated dependencies rebuild objects when their included headers change.
-include $(DEQUE_OBJS:.o=.d) obj/analysis.d $(COVERAGE_OBJS:.o=.d) $(TEST_OBJS:.o=.d)
