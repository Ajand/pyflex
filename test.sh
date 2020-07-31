#!/bin/bash

# Pull the docker image
docker pull reflexer/testchain-pyflex:unit-testing

# Remove existing container if tests not gracefully stopped
docker-compose down

# Start ganache
docker-compose up -d ganache

# Start parity and wait to initialize
docker-compose up -d parity
sleep 2

# Run the tests
py.test --cov=pyflex --cov-report=term --cov-append tests/ $@
TEST_RESULT=$?

# Cleanup
docker-compose down

exit $TEST_RESULT
