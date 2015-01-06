#!/usr/bin/env bash

# Install script for BPM, based off BCE.

# One note: in virtualbox machine settings, changed Audio to enabled, with defaults CoreAudio and ICH AC97)
# Also ran this on host so that symlinks can be created in shared folder:
# VBoxManage setextradata BCE-0.1.3dev VBoxInternal2/SharedFoldersEnableSymlinksCreate/bpm-bce-mods 1
# from template:
# VBoxManage setextradata <VM_NAME> VBoxInternal2/SharedFoldersEnableSymlinksCreate/<SHARE_NAME> 1

# Record changes made.
etckeeper init

APT_GET="apt-get -q -y"
#APT_GET="apt-get"
ORIGDIR=`pwd`

# Make heredoc variable assignment pretty.
define(){ read -r -d '' ${1} || true; }

# Install/remove .deb packages with apt-get.
# First argument is install|remove
# Second argument is a newline-delimited list of packages (# comment lines allowed).
# Third argument is message to echo to console.
apt_get_packages(){
    echo "${3}"
    # The grep bit allows us to have comments in the packages file
    # The quotation marks around ${1} preserves newlines.
    $APT_GET ${1} $(grep '^[^#]' <(echo "${2}")) && \
    $APT_GET clean && \ # help avoid running out of disk space
    echo DONE: ${3} || echo FAIL: ${3}
}

# Package installs will fail if we are not up to date.
apt_get_update(){
    $APT_GET update
}

# Clone and set up python package from github.
# First argument is base github url.
# Second argument is specific repo (package) on github.
python_clone_and_setup(){
    cd /usr/local/src
    git clone ${1}/${2}
    cd ${2}
    python setup.py install
    cd $ORIGDIR
}

add_bpm_repositories(){
    # Add neurodebian and sil.org repositories.
    msg="BPM-BCE: Adding Linguistics repositories..."
    echo "$msg"
    # neurodebian
    wget -O- http://neuro.debian.net/lists/trusty.us-ca.full | \
    tee /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key adv --recv-keys --keyserver hkp://pgp.mit.edu:80 2649A5A9 && \
    # sil.org
    echo "deb http://packages.sil.org/ubuntu trusty main" > /etc/apt/sources.list.d/sil.sources.list && \
    wget http://packages.sil.org/sil.gpg -O- | apt-key add - && \
    # ppa for ffmpeg
    add-apt-repository ppa:mc3man/trusty-media && \
    echo DONE: $msg || echo FAIL: $msg
}

install_standard_packages(){
    # These are packages that install from repositories already enabled in BCE.
define STDPKGS <<'EOF'
imagemagick
praat
python-nltk
sox
wavesurfer

# This one is needed so that praat is not removed automatically when
# pulseaudio is removed.
osspd-alsa

# The following packages are needed in order to build espsfree-* on the vm.
# They will no longer be necessary and can be removed when espsfree-*
# can be downloaded as a binary package.
#build-essential  # already in BCE
byacc
#debhelper  # already in BCE
devscripts
flex
libatlas-dev

# This one is needed for ifcformant
# Will be better to precompile ifcformant and just download it.
subversion

# Needed to compile esps.
libc6-dev-i386

# Needed to compile htk (results in package authentication warnings).
libx11-dev:i386

# Needed for EdgeTrak
# TODO: wine depends on ttt-mscorefont-installer and requires user to accept a license agreement
wine
EOF
    apt_get_packages install "$STDPKGS" "BPM-BCE: Installing Linguistics packages from standard repositories..."
    apt_get_packages "remove --purge --assume-yes" pulseaudio "BPM-BCE: Removing pulseaudio..."
}


install_neuro_packages(){
    # Packages from the neurodebian repository.
define NEUROPKGS <<'EOF'
opensesame
EOF
    apt_get_packages install "$NEUROPKGS" "BPM-BCE: Installing Linguistics packages from neurodebian repository..."
}

install_fieldworks(){
    # Packages from the sil.org repository.
    # TODO: fieldworks requires user to accept a license agreement
define SILPKGS <<'EOF'
fieldworks-applications
EOF
    apt_get_packages install "$SILPKGS" "BPM-BCE: Installing Linguistics packages from sil.org repository..."
}

install_ffmpeg(){
define FFMPEGPKGS <<'EOF'
ffmpeg
EOF
    apt_get_packages install "$FFMPEGPKGS" "BPM-BCE: Installing Linguistics packages from ffmpeg repository..."
}

install_phylogenetics(){
    # These are packages Lev is interested in.
define LEVPKGS <<'EOF'
mrbayes
beast-mcmc
EOF
    apt_get_packages install "$LEVPKGS" "BPM-BCE: Installing Linguistics packages for phylogenetics..."
    msg="Installing Mesquite"
    echo $msg
    cd /opt && \
    wget https://github.com/MesquiteProject/MesquiteCore/releases/download/3.01/Mesquite301_Linux.tgz && \
    tar xf Mesquite301_Linux.tgz && \
    chmod +x /opt/Mesquite_Folder/mesquite.sh && \
    chown -R oski.oski /opt/Mesquite_Folder/ && \
    rm Mesquite301_Linux.tgz && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

install_lingpy(){
    # Python packages to pull and set up from github.
    GITBASE=https://github.com/rsprouse
    python_clone_and_setup $GITBASE klsyn
    python_clone_and_setup $GITBASE audiolabel
    python_clone_and_setup $GITBASE paramdraw
    python_clone_and_setup $GITBASE maedasyn

    # Install from ucblingmisc.
    msg="Install miscellaneous Linguistics utilities."
    echo $msg
    mkdir /usr/local/lib/site_perl && \
    cd /usr/local/lib/site_perl && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/perl/SoundLabel.pm && \
    cd /usr/local/bin && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/perl/concat_pyalign_textgrids && \
    chmod +x concat_pyalign_textgrids && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/perl/convertlabel && \
    chmod +x convertlabel && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/perl/make_text_grids && \
    chmod +x make_text_grids && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/python/fricative_analysis.py && \
    chmod +x fricative_analysis.py && \
    wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/python/vc_transitions && \
    chmod +x vc_transitions && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

install_esps(){
    # esps install
    cd /usr/local/src
    git clone https://github.com/rsprouse/espsfree
    cd espsfree/espsfree-dev
    debuild --no-tgz-check -us -uc
    cd ..
    # Use * in the .deb name so we don't have to edit this script when the version changes.
    dpkg -i espsfree-dev*.deb
    cd espsfree-lib
    debuild --no-tgz-check -us -uc
    cd ..
    dpkg -i espsfree-lib*.deb
    cd espsfree-util
    debuild --no-tgz-check -us -uc
    cd ..
    dpkg -i espsfree-util*.deb
    cd espsfree-signal
    debuild --no-tgz-check -us -uc
    cd ..
    dpkg -i espsfree-signal*.deb
    rm *.build
    rm *.changes
    rm *.deb
    rm *.dsc
    rm *.tar.gz
    cd $ORIGDIR
}


install_ifcformant(){
    # Install ifcformant.
    msg="Install ifcformant."
    echo $msg
    cd /usr/local/src && \
    wget https://github.com/rsprouse/ucblingmisc/raw/master/ifcformant-bpm/ifcformant-bpm-bce.tar && \
    tar xf ifcformant-bpm-bce.tar && \
    cd ifcformant-bpm-bce && \
    ./install-bpm.sh && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

install_htk(){
    # Install HTK.
    msg="Install HTK 3.4.1 and p2fa (pyalign)."
define htkprompt <<'EOF'
The HTK toolkit requires a username and password to download. These can be obtained at no cost
by registering at http://htk.eng.cam.ac.uk/register.shtml.

If you choose to skip registration HTK will not be installed. The Penn Force Aligner p2fa (pyalign)
will also not be installed since it requires HTK.

Provide a username to download HTK 3.4.1 or press <Enter> to skip HTK/p2fa installation.
EOF
    echo $msg
    echo "$htkprompt"
    read username
    if [ $username != '' ]; then
        echo "Provide your HTK password:"
        read password
        if [ $password != '' ]; then
            cd /usr/local/src && \
            wget --user $username --password $password http://htk.eng.cam.ac.uk/ftp/software/HTK-3.4.1.tar.gz && \
            tar xf HTK-3.4.1.tar.gz && \
            cd htk && \
            # Patch up HRec.c. See https://groups.google.com/forum/#!topic/fave-users/wDScrDkF44Q
            # and https://github.com/JoFrhwld/FAVE/wiki/HTK-on-OS-X#fixing-htk-source for details.
            perl -pi.orig -e 's/if \(dur<=0 && labid != splabid\) HError\\(8522,"LatFromPaths: Align have dur<=0 ")/if (dur<=0 && labpr != splabid) HError(8522,"LatFromPaths: Align have dur<=0 ")/' HTKLib/HRec.c && \
            ./configure && \
            make all && \
            make install && \
            cd /opt && \
            wget http://www.ling.upenn.edu/phonetics/p2fa/p2fa_1.003.tgz && \
            tar xzvf p2fa_1.003.tgz && \
            cd /usr/local/bin && \
            wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/python/pyalign && \
            echo DONE: $msg || echo FAIL: $msg
            cd $ORIGDIR
        fi
    fi
}

install_edgetrak(){
    # Install EdgeTrak.
    # EdgeTrak will run with:
    #   wine /opt/EdgeTrak/EdgeTrak.exe
    # TODO: edgetrak fails to run with 'unexpected main window position' error
    msg="Install EdgeTrak."
    echo $msg
    cd /opt
    wget http://speech.umaryland.edu/programs/Edgetrak.zip && \
    unzip Edgetrak.zip && \
    rm Edgetrak.zip && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

install_mcr(){
    # Install Matlab MCR.
    # TODO: mcr also involves agreeing to license
    msg="Installing Matlab runtime."
    echo $msg
    cd /usr/local/src && \
    mkdir matlab_installer && \
    cd matlab_installer && \
    wget http://www.mathworks.com/supportfiles/downloads/R2014b/deployment_files/R2014b/installers/glnxa64/MCR_R2014b_glnxa64_installer.zip && \
    unzip MCR_R2014b_glnxa64_installer.zip && \
    ./install -mode silent -agreeToLicense yes -destinationFolder /opt/matlab/2014b && \
    rm MCR_R2014b_glnxa64_installer.zip && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

install_display_acq(){
    # Install display_acq.
    # To run with installed mcr: run_display_acq.sh /opt/matlab/2014b/v84/ acqfile.mat
    # TODO: fix initial display size and location
    msg="Installing display_acq."
    echo $msg
    cd /usr/local/bin && \
    wget https://github.com/rsprouse/ucblingmisc/raw/master/display_acq-bpm/display_acq_2014b.tar && \
    tar xf display_acq_2014b.tar && \
    echo DONE: $msg || echo FAIL: $msg
    cd $ORIGDIR
}

case "$1" in

apt-get)
    apt_get_update
    ;;

bpm-public)
    add_bpm_repositories
    apt_get_update
    install_standard_packages
    install_neuro_packages
    install_ffmpeg
    install_lingpy
    install_esps
    install_ifcformant
    install_edgetrak
    install_display_acq
    ;;

bpm-ucbling)
    install_htk
    install_mcr
    ;;

neuro)
    install_neuro_packages
    ;;

ffmpeg)
    install_ffmpeg
    ;;

lingpy)
    install_lingpy
    ;;

esps)
    install_esps
    ;;

ifcformant)
    install_ifcformant
    ;;

htk)
    install_htk
    ;;

edgetrak)
    install_edgetrak
    ;;

mcr)
    install_mcr
    ;;

display_acq)
    install_display_acq
    ;;

phylogenetics)
    install_phylogenetics
    ;;

fieldworks)
    install_fieldworks
    ;;

help)
    # TODO: better help message
    echo "Usage: bpm_update package"
    ;;

list)
    # TODO: echo list packages that can be installed/updated
    echo "Usage: bpm_update package"
    ;;

*)
    echo "Usage: bpm_update package"
    ;;

esac

# Install voicesauce. This will require getting the source and compiling for linux.
#cd /usr/local/src
#wget http://www.phonetics.ucla.edu/voicesauce/current/VoiceSauce_bin.zip
#cd $ORIGDIR


# TODO: voicesauce, flowanalyzer
