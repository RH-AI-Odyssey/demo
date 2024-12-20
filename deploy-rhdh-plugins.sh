#!/bin/bash

# Create a new build configuration
oc new-build httpd --name=plugin-registry --binary -n demo-operators-comps

# Start a build from the contents of our deploy directory for the initial image
oc start-build plugin-registry --from-dir=./rhdh-plugins --wait -n demo-operators-comps

# Create the plugin registry httpd instance
oc new-app --image-stream=plugin-registry -n demo-operators-comps