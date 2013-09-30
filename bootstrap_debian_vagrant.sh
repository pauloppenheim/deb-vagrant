#!/bin/bash

#The MIT License (MIT)
#
#Copyright (c) 2013 Paul Oppenheim
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.


VM_NAME=deb71s64-vagrant
SSH_VMHOST_PORT=9022
# gnome-keyring doesn't currently support ECDSA
# https://bugzilla.gnome.org/show_bug.cgi?id=641082
#KEYTYPE=ecdsa
#KEYBITS=521
KEYTYPE=rsa
KEYBITS=4096

TIMEWAIT_BOOT=15
TIMEWAIT_HALT=5

KEYF=$VM_NAME.id_$KEYTYPE


echo
date --iso-8601=seconds
echo


# vboxmanage controlvm "$VM_NAME" poweroff
vboxmanage modifyvm "$VM_NAME" --natpf1 "guestssh,tcp,,$SSH_VMHOST_PORT,,22"
vboxmanage startvm "$VM_NAME" --type headless
# vboxheadless doesn't return control, despite being "recommended" option in docs
#vboxheadless --startvm "$VM_NAME" --vrde off
echo
echo "You will need to enter VM root password, wait, SSH key passphrase, wait, 3 user logins, then all should be automatic."
echo
echo wait $TIMEWAIT_BOOT sec for boot
echo
for i in $(seq $TIMEWAIT_BOOT) ; do
	echo -n .
	sleep 1
done
echo

#echo SSH_USERNAME:
#read SSH_USERNAME
SSH_USERNAME=$USER
#echo "'${SSH_USERNAME}'"

#ssh -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost 'su -l -- aptitude -y install sudo'
#ssh -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost 'echo "su - -c aptitude -- -y install sudo ; exit" | python -c "import pty; pty.spawn(\"/bin/bash\")"'
#ssh -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost 'python -c "import pty; pty.spawn(\"/bin/su - -c aptitude -- -y install sudo\".split(\" \"))"'
#ssh -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost <<EOF su -l -- aptitude -y install sudo
#EOF

echo
echo -e "root SSH:\t\tinstall sudo, add $SSH_USERNAME to sudoers"
echo
#ssh -p $SSH_VMHOST_PORT -l root localhost "aptitude -y install sudo ; echo includedir /etc/sudoers.d >> /etc/sudoers ; echo '${SSH_USERNAME} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/${SSH_USERNAME}"
ssh -p $SSH_VMHOST_PORT -l root localhost "aptitude -y install sudo ; echo '${SSH_USERNAME} ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/${SSH_USERNAME}"


# SSH keys - make key, transfer, no more pass
# (use keyfile in case it's already there from prior run)
ssh-keygen -t $KEYTYPE -b $KEYBITS -f $KEYF
# assuming you already have an agent running, true in most desktop OSes now
# nevermind, run our own...
eval $(ssh-agent)
ssh-add $KEYF

ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "mkdir ~/.ssh ; chmod 700 ~/.ssh "
scp -i $KEYF -P $SSH_VMHOST_PORT $KEYF.pub ${SSH_USERNAME}@localhost:~/.ssh/$KEYF.pub
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "chmod 600 ~/.ssh/$KEYF.pub ; cp -a ~/.ssh/$KEYF.pub ~/.ssh/authorized_keys"

# install tools
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo aptitude -y purge virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11 virtualbox-ose-guest-x11"
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo aptitude -y install build-essential dkms linux-headers"
#ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo aptitude -y install ruby rubygems"
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo aptitude clean"


# install virtualbox guest additions
vboxmanage storageattach deb71s64-vagrant --storagectl IDE --port 1 --device 0 --type dvddrive --medium /usr/share/virtualbox/VBoxGuestAdditions.iso
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo mount /dev/sr0 /media/cdrom0"
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo /media/cdrom0/VBoxLinuxAdditions.run"
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo umount /media/cdrom0 ; sudo eject"
ssh -i $KEYF -p $SSH_VMHOST_PORT -l ${SSH_USERNAME} localhost "sudo poweroff"
echo
echo wait $TIMEWAIT_HALT sec for shutdown
echo
for i in $(seq $TIMEWAIT_HALT) ; do
	echo -n .
	sleep 1
done
echo

#vboxmanage controlvm "$VM_NAME" poweroff
vboxmanage modifyvm "$VM_NAME" --natpf1 delete "guestssh"
cat Vagrantfile.template | sed "s/USERNAME_SENTINEL/$SSH_USERNAME/" | sed "s/KEYFILE_SENTINEL/$KEYF/" > Vagrantfile
rm $VM_NAME.box
vagrant package --base $VM_NAME --vagrantfile Vagrantfile --output $VM_NAME.box

#remove keys, kill agent
ssh-add -D
kill $SSH_AGENT_PID

echo
date --iso-8601=seconds
echo

echo "You will need to copy both the private and public keys where they will be accessible - usually into each vagrant project that will run with this box."


