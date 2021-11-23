echo "Warning: will not rebuild automatically. Ensure build is current."
echo "Recording profile..."
perf record -g ./sob

echo "Demangling..."
perf script -F +pid | ddemangle > /tmp/test.perf
echo "Done. See /tmp/test.perf"
