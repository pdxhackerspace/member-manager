# User Guide

Admin-facing notes for MemberZone features.

## Automated nags

Settings → **Nags** lists automated member reminders. Each nag can be enabled or disabled independently. Preview counts and the due-member list are always visible, even when a nag is disabled.

### Slack signup reminder

Reminds **active members without a linked Slack account** to join the workspace. The daily job runs at 7:00 AM.

**Timing** (Settings → Membership settings):

- **Initial delay after approval** — days after application approval before the first reminder
- **Repeat interval** — minimum days between reminders to the same member

Members without an approved application use their member record creation date as the starting point.

**Email copy** is editable under Settings → Email templates (`Slack Signup Reminder`). The template sends immediately when the nag runs (it does not wait in the outbound mail review queue).

The nag only sends when the Slack member source is enabled.
