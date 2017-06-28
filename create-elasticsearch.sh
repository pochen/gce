#! /bin/bash
# Create a GCE elasticsearch.
# Usage create-elasticsearch.sh (prod | dev) ( Server_Number )
# eg. ./create-elasticsearch.sh dev 01 # recommend 2 or 3 digit zero-padded depending on size of cluster
# Note: currently the create and add node are the same script. We may leverage to add a text file to keep track of all nodes' IPs and upload it to google storage bucket. TODO later
set -eux

if [ $# -lt 2 ]; then
  echo 1>&2 "$0: not enough arguments"
  exit 2
elif [ $# -gt 2 ]; then
  echo 1>&2 "$0: too many arguments"
  exit 2
fi

CLUSTER=$1
NODE=$2
DISK="elasticsearch-$CLUSTER-$NODE-data"
NAME="elasticsearch-$CLUSTER-$NODE"
# can likely convert following to case statement -- TODO later
if [ `echo "$NODE % 4" | bc` -eq 1 ]; then
  REGIONZONE="us-central1-c"
elif [ `echo "$NODE % 4" | bc` -eq 2 ]; then
  REGIONZONE="us-central1-a"
elif [ `echo "$NODE % 4" | bc` -eq 3 ]; then
  REGIONZONE="us-central1-b"
else
  REGIONZONE="us-central1-f"
fi

#SSD quota of 20TB reached, they are increasing it to 30TB
#gcloud compute disks create $DISK --size 1000 --type "pd-ssd" --zone $REGIONZONE
gcloud compute disks create $DISK --size 1000 --type "pd-standard" --zone $REGIONZONE
gcloud compute --project "scaled-inference" instances create "$NAME" \
  --zone "$REGIONZONE" \
  --machine-type "custom-10-65536" \
  --network "default" \
  --metadata "CLUSTER=$CLUSTER,NODE=$NODE,ESDISK=$DISK,startup-script-url=gs://amp2-elasticsearch/scripts/startup-node.sh,ES_HEAP_SIZE=28g" \
  --maintenance-policy "MIGRATE" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --tags "http-server","https-server" \
  --image "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20170307" \
  --boot-disk-size "30" \
  --boot-disk-type "pd-ssd" \
  --boot-disk-device-name $NAME \

gcloud compute instances attach-disk $NAME --disk $DISK --device-name $DISK --zone $REGIONZONE
sleep 15
gcloud compute ssh $NAME --command "sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-$DISK" --zone $REGIONZONE

