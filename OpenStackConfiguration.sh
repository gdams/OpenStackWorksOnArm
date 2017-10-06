. admin-openrc 

# Download ARM images and upload into OpenStack (Glance)

IMG_URL=https://dl.fedoraproject.org/pub/fedora-secondary/releases/26/CloudImages/aarch64/images/Fedora-Cloud-Base-26-1.5.aarch64.qcow2
IMG_NAME=Fedora-26-arm64
OS_DISTRO=fedora
wget -q -O - $IMG_URL | \
glance  --os-image-api-version 2 image-create --protected True --name $IMG_NAME --property hw_firmware_type=uefi \
	--visibility public --disk-format raw --container-format bare --property os_distro=$OS_DISTRO --progress

IMG_URL=https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-arm64.tar.gz
IMG_NAME=xenial-server-arm64
OS_DISTRO=ubuntu
wget $IMG_URL
tar xfvz ubuntu-16.04-server-cloudimg-arm64.tar.gz xenial-server-cloudimg-arm64.img
glance  --os-image-api-version 2 image-create --protected True --name $IMG_NAME --file xenial-server-cloudimg-arm64.img \
	--property hw_firmware_type=uefi \
	--visibility public --disk-format raw --container-format bare --property os_distro=$OS_DISTRO --progress
rm xenial-server-cloudimg-arm64.img
rm ubuntu-16.04-server-cloudimg-arm64.tar.gz


# setup provider networking

GATEWAY=`ip route list | egrep "^default" | cut -d' ' -f 3`
IP=`hostname -I | cut -d' ' -f 1`
SUBNET=`ip -4 -o addr show dev bond0 | grep $IP | cut -d ' ' -f 7`

openstack network create  --share --external \
  --provider-physical-network provider \
  --provider-network-type flat provider

# use public IP addresses provided by Packet
openstack subnet create --network provider \
  --dns-nameserver 8.8.4.4 --gateway $GATEWAY \
  --subnet-range $SUBNET provider

openstack router create provider-gw
openstack router set --external-gateway provider provider-gw

openstack network create internal
openstack subnet create --dhcp --network internal \
	--allocation-pool start=192.168.100.100,end=192.168.100.200 \
	--subnet-range 192.168.100.0/24 internal
openstack router create internal-gw
openstack router add subnet internal-gw internal
openstack router set --external-gateway provider internal-gw


# some default flavors
openstack flavor create --ram 512   --disk 1   --vcpus 1 m1.tiny
openstack flavor create --ram 2048  --disk 20  --vcpus 1 m1.small
openstack flavor create --ram 4096  --disk 40  --vcpus 2 m1.medium
openstack flavor create --ram 8192  --disk 80  --vcpus 4 m1.large
openstack flavor create --ram 16384 --disk 160 --vcpus 8 m1.xlarge

# spin up a test instance
openstack keypair create default > default.pem
openstack server create --flavor m1.medium --image xenial-server-arm64 --key-name default --network internal ubuntu
