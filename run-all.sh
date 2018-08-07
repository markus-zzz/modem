#!/bin/bash

set -x

vvp -M. -mvpi_axi_master modem.vvp &

sleep 1

./axi_master_client

