# Erlang Mini SMPP/SMSC Simulator

## About
A self-learning Erlang/OTP project that simulates a simplified SMPP/SMSC message flow.

## Current Features
- TCP listener
- OTP supervision
- Dynamic client sessions
- Simulated BIND authentication
- Simulated SMS submission
- ETS message storage
- Unique message IDs
- Delivery receipt simulation
- Concurrent delivery workers

## Current Flow
Client
 → TCP Listener
 → SMPP Session
 → Authentication
 → SMS Submit
 → ETS Store
 → Delivery Worker
 → Delivery Receipt

## Run
rebar3 compile
rebar3 shell

## SMPP Port
2775

## Test Commands
BIND testuser test123

SUBMIT BANK 94771234567 Your OTP is 123456

