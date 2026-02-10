# Messages Chat Component

## Overview

The Messages Chat component allows users to view and send messages related to a specific record. Messages are synced via PowerSync using the `records_messages` table.

## Features

- Display chat-style message history for a record
- Send new messages
- Delete own messages
- Real-time sync via PowerSync
- Responsive layout with message bubbles
- Timestamp display

## Usage in Layout Configuration

Add the messages chat component to your layout JSON:

```json
{
  "id": "messages",
  "type": "object",
  "component": "messages_chat",
  "label": "Nachrichten"
}
```

### Example: Adding Messages Tab

```json
{
  "type": "tabs",
  "id": "main_tabs",
  "items": [
    {
      "id": "info",
      "type": "form",
      "label": "Info",
      "properties": [...]
    },
    {
      "id": "messages",
      "type": "object",
      "component": "messages_chat",
      "label": "Nachrichten"
    }
  ]
}
```

### Example: Messages in a Card

```json
{
  "type": "card",
  "label": "Kommunikation",
  "children": [
    {
      "id": "messages",
      "type": "object",
      "component": "messages_chat"
    }
  ]
}
```

## Component Properties

- **recordId** (automatic): The ID of the current record is automatically passed from `widget.rawRecord.id`
- **readOnly** (optional): Set to `true` to prevent sending/deleting messages (default: `false`)

## Database Requirements

The component requires the `records_messages` table to be synced via PowerSync:

```sql
CREATE TABLE public.records_messages (
  id uuid PRIMARY KEY,
  created_at timestamp with time zone,
  note text,
  user_id uuid,
  records_id uuid,
  -- Access control fields (auto-populated by triggers)
  responsible_administration uuid,
  responsible_state uuid,
  responsible_provider uuid,
  responsible_troop uuid
);
```

## Sync Rules

Ensure PowerSync sync rules include `records_messages`:

```yaml
user_organizations:
  data:
    - SELECT id, created_at, note, user_id, records_id FROM "public"."records_messages"
      WHERE responsible_administration = bucket.organization_id
      OR responsible_state = bucket.organization_id
      OR responsible_provider = bucket.organization_id

troop_records:
  data:
    - SELECT id, created_at, note, user_id, records_id FROM "public"."records_messages"
      WHERE responsible_troop = bucket.troop_id
```

## UI Features

### Message Display

- Messages from the current user appear on the right (blue)
- Messages from other users appear on the left (gray)
- Each message shows timestamp in format: `dd.MM.yyyy HH:mm`
- Own messages show a delete button

### Message Input

- Text field at the bottom for new messages
- Send button or press Enter to send
- Automatically scrolls to newest message

### Empty State

- Shows "Keine Nachrichten" when no messages exist

## Error Handling

The component handles:

- Missing record ID (shows error message)
- Failed message sends (shows SnackBar)
- Failed message deletes (shows SnackBar)
- Loading states (shows CircularProgressIndicator)

## Dependencies

Required services:

- `DatabaseService` - PowerSync database access
- `Supabase.instance.client.auth.currentUser` - Get current user

Required packages:

- `intl` - Date formatting
- `supabase_flutter` - Authentication
