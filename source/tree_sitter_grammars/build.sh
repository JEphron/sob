gcc -shared -o json_parser.so -fPIC json_parser.c
gcc -shared -o js_parser.so -fPIC js_parser.c js_scanner.c
