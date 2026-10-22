# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-31 (after V49).

## E10 Community transport

### CF-31 One broadcast in the community channel
- Goal: the community transport (CF-28 part 2b) sends one message to the community channel instead of a whisper to each member running the addon, so traffic no longer grows with the number of members.
- Depends on V49: can addons send addon messages in the community channel, and do they arrive at the other members (run 1: the send is accepted, but no copy comes back to the sender)? If V49 says no, this story is dropped and the whispers stay.
- Keeps everything from CF-28: 255-byte parts, MISS and resend, the accept rules (the sender maps to a community member; a record claimed as own must contain the sending character).
- Manual (2 clients in the community, not Battle.net friends): records, level-ups and group asks arrive; `/cf sync debug` shows one channel send instead of a whisper per member.

## E11 Ease of use

