FLAGS= -DIOSTD
LDFLAGS=--subsystem windows

default: 
	make LDFLAGS="--subsystem console" main.exe

mem:
	make FLAGS="-DMEM" main.exe

net:
	make FLAGS="-DIONET -DIPADDR=10,0,2,11 -DPORT=1919" main.exe

inet:
	make FLAGS="-DIOWININET -DHTTPINTERVAL=5000 -DHTTPHOST=\\\"10.0.2.11\\\"" main.exe

main.obj: *.asm
	nasm $(FLAGS) -f win64 -g main.asm

main.exe: main.obj
	ld $(LDFLAGS) -e main -o main.exe main.obj

prod: main.exe
	strip main.exe
	./main.exe < tests.fth
	ls -l main.exe
	md5sum main.exe

min:
	(cat minim.fth; cat core.fth; echo -e "\x01") | ./bins/streams.exe | grep -A1 BEGIN | tail -n 1 > mincore.fth

test:
	cat tests.fth | ./main.exe | cat

clean:
	rm main.exe main.obj

log:
	git log --date="format:%Y-%m-%d" --pretty="[36;2m%ad [0m[36;1m%s[0m" | tac

bench: prod min
	strip main.obj
	ls -l main.obj
