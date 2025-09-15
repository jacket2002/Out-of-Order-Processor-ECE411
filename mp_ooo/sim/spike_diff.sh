# Check if an argument is provided for ELF
if [ -z "$1" ]; then
    echo "Usage: $0 <ELF argument>"
    exit 1
fi

# Run make command with the specified ELF argument
# make spike ELF=./bin/$1
# make spike ELF=../testcode/cp3_release_benches/$1
make spike ELF=../testcode/$1
# make spike ELF=../testcode/additional_testcases/$1
retval=$?

# Exit if make command fails
if [ $retval -ne 0 ]; then
    echo -e "\033[0;31mMake failed \033[0m"
    exit $retval
fi

# Run diff command with specified log files
diff spike/commit.log spike/spike.log > spike/diff.log
retval=$?

set -e

if [ $retval -eq 0 ]; then
    echo -e "\033[0;32mSpike diff Passed \033[0m"
    exit 0
else
    echo -e "\033[0;31mSpike diff Failed \033[0m"
    echo "first 10 lines of spike diff:"
    head -n 10 spike/diff.log
    exit $retval
fi
