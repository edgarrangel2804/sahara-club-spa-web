// Centralised definition of which booking statuses are considered "active"
// (visible in the agenda by default). Used by BookingSyncService and tests.

/// Statuses included in the default "active" agenda view.
const Set<String> activeBookingStatuses = {
  'scheduled',
  'pending',
  'pending_reception',
  'pending_payment',
  'payment_received',
  'confirmed',
  'checked_in',
  'in_progress',
  'completed',
  'awaiting_payment',
  'paid',
};

/// Statuses that prove a service was finished (not merely started).
const Set<String> attendedTerminalStatuses = {
  'completed',
  'awaiting_payment',
};

/// Returns true when [status] is part of the active agenda filter.
bool isActiveBookingStatus(String status) =>
    activeBookingStatuses.contains(status);

/// Returns true when [status] proves the service was completed.
bool isAttendedTerminalStatus(String status) =>
    attendedTerminalStatuses.contains(status);
