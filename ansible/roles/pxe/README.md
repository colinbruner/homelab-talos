# PXE
I want to run a small VM run on my QNAP (for now) NAS Server that can assist in PXE booting
other baremetal and virtual machines on my network.

The goal of this is to be able to easily boot and reset Talos Linux for a home office Kubernetes cluster.

## Objective
Install pxelinux, tftpd, nginx on a target server and mount a remote NFS share drive containing image ISOs