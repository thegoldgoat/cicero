'''
    This file is used to measure the compile time and compile size of all these combinations:
    - Different benchmarks
    - Different compilers
    - Different optimizations (ON|OFF)
'''

import csv
import statistics
import time
import tqdm
import sys
import os

OUTPUT_FILENAME = 'all_compiletime_compilesize.csv'

BENCHMARKS = [
    # (Benchmark name, benchmark file)
    ('brill4', 'input/brill4.regex'),
    ('protomata', 'input/protomata4.regex'),
    ('powerEN4', 'input/powerEN4.regex'),
    ('dotstar', 'input/dotstar4.regex')
]

COMPILERS = [
    # (Compiler name, compiler path)
    ('c++', '/home/andrea/src/cicero_compiler_cpp'),
    ('python', '/home/andrea/publicsrc/necst/cicero_compiler')
]

OPTIMIZATIONS = [
    # (Optimization name, optimization flag)
    ('O0', False),
    ('O1', True)
]


def check_script_arguments():
    for benchmark in BENCHMARKS:
        if not os.path.isfile(benchmark[1]):
            print(f"File {benchmark[1]} does not exist.")
            quit(1)
    for compiler in COMPILERS:
        sys.path.append(compiler[1])
        try:
            import re2compiler
        except ImportError:
            print(f'Could not import cicero compiler from {compiler[1]}')
            sys.exit(1)
        # Try a little compilation
        re2compiler.compile(data='this|that', O1=True)
        sys.path.pop()
        del re2compiler
        del sys.modules['re2compiler']

def print_summary():
    print('-------------------')
    for (compiler_name, _) in COMPILERS:
        for (benchmark_name, __) in BENCHMARKS:
            for (optimization_name, ___) in OPTIMIZATIONS:
                print(f'\t{compiler_name}-{benchmark_name}-{optimization_name}')
    print('-------------------')

def calculate_statistics(values):
    '''
        Calculate:
        - Average
        - Minimum
        - Maximum
        - Quantiles (25%, 50%, 75%)
        - Sum
    '''
    return (statistics.mean(values), min(values), max(values), statistics.quantiles(values, n=4), sum(values))


def main():
    # Before starting, make sure all the compilers paths are correct, and all input files are correct
    check_script_arguments()

    print_summary()

    print('Starting in 10 seconds...')
    try:
        time.sleep(10)
    except KeyboardInterrupt:
        print('Keyboard interrupt detected, quitting.')
        quit(-1)

    output_file = open(OUTPUT_FILENAME, 'w')
    output_writer = csv.writer(output_file)
    output_writer.writerow(['Compiler', 'Benchmark', 'Optimization', 'Compile time (avg)', 'Compile time (min)', 'Compile time (max)', 'Compile time (25% quantile)', 'Compile time (50% quantile)', 'Compile time (75% quantile)',
                            'Compile time (sum)', 'Compile size (avg)', 'Compile size (min)', 'Compile size (max)', 'Compile size (25% quantile)', 'Compile size (50% quantile)', 'Compile size (75% quantile)', 'Compile size (sum)'])

    for compiler in COMPILERS:
        sys.path.append(compiler[1])
        try:
            import re2compiler
        except ImportError:
            print(f'???? Could not import cicero compiler from {compiler[1]} ???? Should have caught this earlier. Skipping this compiler.')
            sys.path.pop()
            continue

        for benchmark in BENCHMARKS:
            for optimization in OPTIMIZATIONS:
                print(f'Compiler: {compiler[0]} | Optimization: {optimization[0]} | Benchmark: {benchmark[0]}')
                print(f'Compiler path: {compiler[1]} | Benchmark file: {benchmark[1]}')

                regexes = []
                with open(benchmark[1], 'r') as f:
                    for line in f:
                        regexes.append(line[:-1])

                # Compile the regexes, while keeping the compile time and size of each regex
                compiled_regexes_times = []
                compiled_regexes_sizes = []

                for regex in tqdm.tqdm(regexes, desc='Compiling regexes'):
                    time_before_compile = time.time()
                    try:
                        compiled_regex = re2compiler.compile(data=regex, O1=optimization[1])
                    except:
                        print(f'Error while compiling regex: "{regex}"')
                        quit(1)
                    compiled_regexes_times.append(
                        time.time() - time_before_compile)
                    # Size is calculated as the number of lines
                    compiled_regexes_sizes.append(compiled_regex.count('\n'))

                # COMPILE TIME:
                time_avg, time_min, time_max, [time_quantile_25, time_quantile_50,
                                               time_quantile_75], time_sum = calculate_statistics(compiled_regexes_times)
                # OUTPUT SIZE:
                size_avg, size_min, size_max, [size_quantile_25, size_quantile_50,
                                               size_quantile_75], size_sum = calculate_statistics(compiled_regexes_sizes)
                output_writer.writerow([compiler[0], benchmark[0], optimization[0], time_avg, time_min, time_max, time_quantile_25, time_quantile_50,
                                        time_quantile_75, time_sum, size_avg, size_min, size_max, size_quantile_25, size_quantile_50, size_quantile_75, size_sum])

        sys.path.pop()
        del re2compiler
        del sys.modules['re2compiler']

if __name__ == '__main__':
    main()
