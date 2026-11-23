import 'package:wayhunter_mobile/core/network/api_client.dart';
import 'package:wayhunter_mobile/shared/domain/models/navigation_refs.dart';

bool isInvitationGuid(String id) =>
    id != '00000000-0000-0000-0000-000000000000' &&
    RegExp(
      r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);

enum InvitationStatus {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const InvitationStatus(this.label);
  final String label;

  static InvitationStatus? fromCode(int code) => switch (code) {
    0 => pending,
    1 => accepted,
    2 => rejected,
    3 => cancelled,
    _ => null,
  };
}

enum InvitationAction {
  accept('Accept invitation', InvitationStatus.accepted),
  reject('Reject invitation', InvitationStatus.rejected),
  cancel('Cancel invitation', InvitationStatus.cancelled);

  const InvitationAction(this.label, this.status);
  final String label;
  final InvitationStatus status;
}

class TripInvitation {
  const TripInvitation({
    required this.id,
    required this.plan,
    required this.sender,
    required this.recipient,
    required this.status,
    required this.createdAtUtc,
  });
  final String id;
  final TripPlanRef plan;
  final UserRef sender;
  final UserRef recipient;
  final InvitationStatus status;
  final DateTime createdAtUtc;

  TripInvitation withStatus(InvitationStatus status) => TripInvitation(
    id: id,
    plan: plan,
    sender: sender,
    recipient: recipient,
    status: status,
    createdAtUtc: createdAtUtc,
  );

  factory TripInvitation.fromJson(Object? json) {
    if (json case {
      'invitationId': final String id,
      'tripPlanId': final String plan,
      'senderUserId': final String sender,
      'recipientUserId': final String recipient,
      'status': final int code,
      'createdAtUtc': final String created,
    } when [id, plan, sender, recipient].every(isInvitationGuid)) {
      final status = InvitationStatus.fromCode(code);
      final date = DateTime.tryParse(created);
      if (status != null &&
          date?.isUtc == true &&
          sender.toLowerCase() != recipient.toLowerCase()) {
        return TripInvitation(
          id: id.toLowerCase(),
          plan: TripPlanRef(plan.toLowerCase()),
          sender: UserRef(sender.toLowerCase()),
          recipient: UserRef(recipient.toLowerCase()),
          status: status,
          createdAtUtc: date!,
        );
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}

class InvitationDecision {
  const InvitationDecision({
    required this.invitationId,
    required this.status,
    this.memberId,
  });
  final String invitationId;
  final InvitationStatus status;
  final String? memberId;

  factory InvitationDecision.fromJson(Object? json) {
    if (json case {
      'invitationId': final String id,
      'status': final int code,
      'memberId': final String? member,
    } when isInvitationGuid(id)) {
      final status = InvitationStatus.fromCode(code);
      if (status != null &&
          (status == InvitationStatus.accepted
              ? member != null && isInvitationGuid(member)
              : member == null)) {
        return InvitationDecision(
          invitationId: id.toLowerCase(),
          status: status,
          memberId: member,
        );
      }
    }
    throw const ApiException(ApiError.invalidResponse);
  }
}
