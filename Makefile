maintarget := package install

all: clean
	FINALPACKAGE=0 && $(MAKE) --directory=springfinity $(maintarget)

clean:
	$(MAKE) --directory=springfinity clean

dirty:
	FINALPACKAGE=0 && $(MAKE) --directory=springfinity $(maintarget)

deb: clean
	FINALPACKAGE=1 && $(MAKE) --directory=springfinity package