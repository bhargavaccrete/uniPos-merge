/// Audit Trail Helper
///
/// Provides utility functions to track changes in models with audit trail fields
///
/// Usage:
/// ```dart
/// // When creating a new item
/// final item = Items(
///   id: uuid.v4(),
///   name: 'Pizza',
///   createdTime: DateTime.now(),
///   // ... other fields
/// );
///
/// // When editing an item
/// item.lastEditedTime = DateTime.now();
/// item.editedBy = 'John Doe'; // or staff ID
/// item.editCount = item.editCount + 1;
/// await item.save();
///
/// // Or use the helper:
/// AuditTrailHelper.trackEdit(item, editedBy: 'John Doe');
/// await item.save();
/// ```

class AuditTrailHelper {
  /// Track an edit on an object with audit trail fields
  /// This updates lastEditedTime, editedBy, and increments editCount
  static void trackEdit<T>(T object, {required String editedBy}) {
    final now = DateTime.now();

    // Use reflection to set the fields
    if (object is dynamic) {
      try {
        object.lastEditedTime = now;
        object.editedBy = editedBy;
        object.editCount = (object.editCount ?? 0) + 1;
      } catch (e) {
        print('Error tracking edit: $e');
        print('Make sure the object has audit trail fields: lastEditedTime, editedBy, editCount');
      }
    }
  }

  /// Initialize audit trail for a new object
  /// Sets createdTime to now and initializes edit tracking
  static void initializeAuditTrail<T>(T object, {String? createdBy}) {
    final now = DateTime.now();

    if (object is dynamic) {
      try {
        object.createdTime = now;
        object.lastEditedTime = null;
        object.editedBy = createdBy;
        object.editCount = 0;
      } catch (e) {
        print('Error initializing audit trail: $e');
        print('Make sure the object has audit trail fields: createdTime, lastEditedTime, editedBy, editCount');
      }
    }
  }

  /// Get a formatted edit history summary
  static String getEditSummary<T>(T object) {
    if (object is dynamic) {
      try {
        final created = object.createdTime as DateTime?;
        final lastEdited = object.lastEditedTime as DateTime?;
        final editedBy = object.editedBy as String?;
        final editCount = object.editCount as int? ?? 0;

        final createdStr = created != null
            ? 'Created: ${_formatDateTime(created)}'
            : 'Created: N/A';

        if (lastEdited != null) {
          return '$createdStr\nLast edited: ${_formatDateTime(lastEdited)}\nEdited by: ${editedBy ?? 'Unknown'}\nTotal edits: $editCount';
        } else {
          return '$createdStr\nNever edited';
        }
      } catch (e) {
        return 'Unable to generate edit summary';
      }
    }
    return 'Object does not support audit trail';
  }

  /// Format DateTime for display
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Check if an object has been edited
  static bool hasBeenEdited<T>(T object) {
    if (object is dynamic) {
      try {
        return object.lastEditedTime != null;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Get time since last edit
  static Duration? timeSinceLastEdit<T>(T object) {
    if (object is dynamic) {
      try {
        final lastEdited = object.lastEditedTime as DateTime?;
        if (lastEdited != null) {
          return DateTime.now().difference(lastEdited);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Get time since creation
  static Duration? timeSinceCreation<T>(T object) {
    if (object is dynamic) {
      try {
        final created = object.createdTime as DateTime?;
        if (created != null) {
          return DateTime.now().difference(created);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}