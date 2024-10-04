#!/bin/bash
curl --interface $1 -X POST http://10.254.241.19/eportal/InterFace.do?method=logout
echo
