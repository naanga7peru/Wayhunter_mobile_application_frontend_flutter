part of 'wallet_screens.dart';

String _redemptionError(Object error) => switch (error) {
  ApiException(kind: ApiError.unauthorized) =>
    'Sign in to access this request.',
  ApiException(kind: ApiError.forbidden) => 'The server denied access.',
  ApiException(kind: ApiError.notFound) => 'Voucher request was not found.',
  ApiException(kind: ApiError.conflict) =>
    'The request conflicts with current wallet or offer state. Refresh before continuing.',
  ArgumentError() => 'Enter a valid request ID.',
  _ => 'Could not reach or verify the voucher service. Try again.',
};

class _LiveRedemptionForm extends StatefulWidget {
  const _LiveRedemptionForm({
    required this.offer,
    required this.reader,
    required this.repository,
  });

  final LiveVoucherOffer offer;
  final WalletReader reader;
  final VoucherRedemptionRepository repository;

  @override
  State<_LiveRedemptionForm> createState() => _LiveRedemptionFormState();
}

class _LiveRedemptionFormState extends State<_LiveRedemptionForm> {
  VoucherRedemptionIntent? _intent;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_intent == null) {
        final balance = await widget.reader.readBalance();
        if (!mounted) return;
        if (balance == null || balance.spendable < 10100) {
          setState(
            () => _error = 'At least 10,100 spendable Coins are required.',
          );
          return;
        }
        final confirmed = await showWayhunterConfirmation(
          context,
          title: 'Confirm voucher request',
          message:
              'The server reserves 10,000 Coins while Admin reviews the request. Approval finalizes the debit.',
          confirmLabel: 'Request voucher',
        );
        if (!mounted || !confirmed) return;
        _intent = widget.repository.prepareCreate(widget.offer.id);
      } else {
        try {
          final request = await widget.repository.readRequest(
            _intent!.requestId,
          );
          if (mounted) await _showRequest(request);
          return;
        } on ApiException catch (error) {
          if (error.kind != ApiError.notFound) rethrow;
        }
      }
      if (!mounted) return;
      final request = await widget.repository.create(_intent!);
      if (mounted) await _showRequest(request);
    } catch (error) {
      if (mounted) setState(() => _error = _redemptionError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRequest(VoucherRedemptionRequest request) async {
    await _open(
      context,
      _VoucherRequestPage(
        repository: widget.repository,
        requestId: request.requestId,
        initialRequest: request,
      ),
    );
    if (mounted) setState(() => _intent = null);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final available =
        offer.cost == 10000 &&
        offer.referenceValueLkr == 100 &&
        offer.availableStock > 0 &&
        offer.isEligible &&
        offer.validUntil.isAfter(DateTime.now());
    return PopScope(
      canPop: !_busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: WayhunterLayout.small,
        children: [
          const Text('Minimum spendable balance · 10,100 Coins'),
          if (_intent case final intent?)
            SelectableText('Request ID: ${intent.requestId}'),
          if (_error case final error?)
            Semantics(liveRegion: true, child: Text(error)),
          if (_busy)
            const Text('Checking voucher request…')
          else if (available || _intent != null)
            WayhunterButton.primary(
              label: _intent == null
                  ? 'Review redemption'
                  : 'Check request and retry',
              onPressed: _submit,
            )
          else
            const Text('This offer is unavailable for redemption.'),
        ],
      ),
    );
  }
}

class _VoucherLookup extends StatelessWidget {
  const _VoucherLookup({required this.repository});
  final VoucherRedemptionRepository repository;

  @override
  Widget build(BuildContext context) => _WalletPage(
    title: 'Find voucher request',
    demo: false,
    children: [
      const Text(
        'Enter a request ID to check its status or open an issued voucher.',
      ),
      _VoucherInput(
        label: 'Request ID',
        action: 'Find request',
        onSubmit: (id) => _open(
          context,
          _VoucherRequestPage(repository: repository, requestId: id),
        ),
      ),
    ],
  );
}

class _VoucherRequestPage extends StatefulWidget {
  const _VoucherRequestPage({
    required this.repository,
    required this.requestId,
    this.initialRequest,
  });

  final VoucherRedemptionRepository repository;
  final String requestId;
  final VoucherRedemptionRequest? initialRequest;

  @override
  State<_VoucherRequestPage> createState() => _VoucherRequestPageState();
}

class _VoucherRequestPageState extends State<_VoucherRequestPage> {
  late Future<VoucherRedemptionRequest> _request = widget.initialRequest == null
      ? widget.repository.readRequest(widget.requestId)
      : Future.value(widget.initialRequest!);
  bool _cancelling = false;
  String? _error;

  void _refresh() => setState(() {
    _request = widget.repository.readRequest(widget.requestId);
  });

  Future<void> _cancel(String reason) async {
    if (_cancelling) return;
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      final confirmed = await showWayhunterConfirmation(
        context,
        title: 'Cancel voucher request?',
        message:
            'The server releases the reservation when it accepts the cancellation.',
        confirmLabel: 'Cancel request',
      );
      if (!mounted || !confirmed) return;
      await widget.repository.cancel(widget.requestId, reason);
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _redemptionError(error));
      _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_cancelling,
    child: _WalletPage(
      title: 'Redemption details',
      demo: false,
      children: [
        SelectableText('Request ID: ${widget.requestId}'),
        if (_error case final error?)
          Semantics(liveRegion: true, child: Text(error)),
        FutureBuilder<VoucherRedemptionRequest>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const WayhunterLoadingView(
                label: 'Checking request status',
              );
            }
            if (snapshot.hasError) {
              return WayhunterErrorView(
                title: 'Could not load voucher request',
                message: _redemptionError(snapshot.error!),
                onRetry: _refresh,
              );
            }
            final request = snapshot.requireData;
            final status = switch (request.status) {
              VoucherRequestStatus.pending => 'Pending Admin review',
              VoucherRequestStatus.approved => 'Approved',
              VoucherRequestStatus.rejected => 'Rejected',
              VoucherRequestStatus.cancelled => 'Cancelled',
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: WayhunterLayout.small,
              children: [
                WayhunterHeader(title: status),
                Text('${formatCoins(request.costCoins)} Coins'),
                if (request.decisionReason case final reason?) Text(reason),
                if (_cancelling) const Text('Checking cancellation…'),
                if (request.status == VoucherRequestStatus.pending &&
                    !_cancelling)
                  _VoucherInput(
                    label: 'Cancellation reason',
                    action: 'Review cancellation',
                    onSubmit: _cancel,
                  ),
                if (request.status == VoucherRequestStatus.approved)
                  WayhunterButton.primary(
                    label: 'Check voucher issuance',
                    onPressed: () => _open(
                      context,
                      _WalletPage(
                        title: 'Issued voucher',
                        demo: false,
                        children: [
                          _WalletRead<IssuedVoucher>(
                            label: 'voucher issuance',
                            read: () => widget.repository.readIssuedVoucher(
                              request.requestId,
                            ),
                            content: _IssuedVoucherContent.new,
                          ),
                        ],
                      ),
                    ),
                  ),
                WayhunterButton.secondary(
                  label: 'Refresh status',
                  onPressed: _refresh,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _VoucherInput extends StatefulWidget {
  const _VoucherInput({
    required this.label,
    required this.action,
    required this.onSubmit,
  });

  final String label;
  final String action;
  final Future<void> Function(String) onSubmit;

  @override
  State<_VoucherInput> createState() => _VoucherInputState();
}

class _VoucherInputState extends State<_VoucherInput> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: WayhunterLayout.small,
      children: [
        TextFormField(
          decoration: InputDecoration(labelText: widget.label),
          controller: _value,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter ${widget.label.toLowerCase()}.'
              : null,
        ),
        WayhunterButton.secondary(
          label: widget.action,
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            FocusScope.of(context).unfocus();
            widget.onSubmit(_value.text.trim());
          },
        ),
      ],
    ),
  );
}

class _IssuedVoucherContent extends StatelessWidget {
  const _IssuedVoucherContent(this.voucher);
  final IssuedVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final status = switch (voucher.status) {
      VoucherIssuanceStatus.unissued => 'Awaiting issuance',
      VoucherIssuanceStatus.failed => 'Issuance failed',
      VoucherIssuanceStatus.issued => 'Voucher issued',
      VoucherIssuanceStatus.used => 'Voucher used',
      VoucherIssuanceStatus.expired => 'Voucher expired',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: WayhunterLayout.small,
      children: [
        WayhunterHeader(title: status),
        Text('LKR ${voucher.referenceValueLkr.toStringAsFixed(2)}'),
        if (voucher.expiresAtUtc case final expiry?)
          Text(
            'Expires ${MaterialLocalizations.of(context).formatMediumDate(expiry.toLocal())}',
          ),
        if (voucher.status == VoucherIssuanceStatus.issued) ...[
          if (voucher.voucherCode case final code?)
            SelectableText('Voucher code: $code'),
          if (voucher.qrPayload case final payload?)
            QrImageView(
              data: payload,
              size: 200,
              backgroundColor: Colors.white,
              semanticsLabel: 'Issued voucher QR code',
              errorStateBuilder: (_, _) =>
                  const Text('Voucher QR could not be displayed.'),
            ),
        ],
      ],
    );
  }
}
