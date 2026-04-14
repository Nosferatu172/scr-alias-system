#echo "going to home directory"
#cd ~/
#echo "downloading git cmus"
#git clone https://github.com/cmus/cmus.git
#echo "going into cmus directory"
#cd /cmus/
#echo "cd /cmus/"
#echo "beginning make"
make
echo "Installing cmus dependancies with apt"
sudo apt install pkg-config libncursesw5-dev libfaad-dev libao-dev libasound2-dev libcddb2-dev libcdio-cdda-dev libdiscid-dev libavformat-dev libavcodec-dev libswresample-dev libflac-dev libjack-dev libmad0-dev libmodplug-dev libmpcdec-dev libsystemd-dev libopusfile-dev libpulse-dev libsamplerate0-dev libsndio-dev libvorbis-dev libwavpack-dev
sudo apt install man -y
echo "Man Pages installed"
echo "Install Cmus itself with apt"
sudo apt-get install cmus -y
echo "cmus -h for help"
cmus -h
