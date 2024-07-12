#!/bin/bash

helm upgrade ingress-nginx \
  ingress-nginx/ingress-nginx \
  --values values.yaml
