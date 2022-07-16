#
# Bootstrap
#

if \
    [ -z $_INSTALL_SCRIPT ]
then
    echo "Please run using install script: exiting..."; exit
fi

_COMMON_PACKAGES="
    alsa-utils \
    alsa-plugins \
    base \
    base-devel \
    bluez \
    bluez-utils \
    brightnessctl \
    bspwm \
    btop \
    btrfs-progs \
    dosfstools \
    dunst \
    efibootmgr \
    feh \
    firefox \
    firewalld \
    git \
    gnome-keyring \
    gnupg \
    gstreamer \
    gstreamer-vaapi \ 
    gst-libav \
    gst-plugin-pipewire \
    gst-plugins-bad \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-ugly \
    intel-ucode \
    kitty \
    libsecret \
    linux \
    linux-firmware \
    linux-headers \
    mkinitcpio \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    openssh \
    picom \
    pinentry \
    pipewire \
    pipewire-alsa \
    pipewire-jack \
    pipewire-pulse \
    playerctl \
    polkit \
    polkit-gnome \
    polybar \
    rofi \
    rsync \
    rust \
    seahorse \
    sof-firmware \
    sudo \
    sxhkd \
    vim \
    vulkan-intel \
    wireplumber \
    xorg-server \
    xorg-xinit \
    xorg-xinput \
    xorg-xrandr \
    xorg-xset \
    zsh
"

_XPS_9310_PACKAGES="
    iio-sensor-proxy \
    intel-media-driver \
    mesa \
    sof-firmware \
"

_MACBOOK_PRO_9_2_PACKAGES="
    libva-intel-driver \
    mesa-amber \
"

_log "Bootstrapping..."

pacstrap /mnt $_COMMON_PACKAGES