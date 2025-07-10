import 'package:flutter/material.dart';
import '../../core/models/rep_model.dart';
import '../../core/services/rep_service.dart';
import '../../core/models/outlet_model.dart';
import '../../core/services/sync_service.dart';

class RepFormScreen extends StatefulWidget {
  final Rep? rep; // If provided, we're editing an existing rep

  const RepFormScreen({super.key, this.rep});

  @override
  State<RepFormScreen> createState() => _RepFormScreenState();
}

class _RepFormScreenState extends State<RepFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repService = RepService();
  final _syncService = SyncService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedOutletId;
  List<Outlet> _outlets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
    if (widget.rep != null) {
      _fullNameController.text = widget.rep!.fullName;
      _emailController.text = widget.rep!.email;
      _selectedOutletId = widget.rep!.outletId;
    }
  }

  Future<void> _loadOutlets() async {
    final outlets = await _syncService.getAllLocalOutlets();
    setState(() {
      _outlets = outlets;
    });
  }

  Future<void> _saveRep() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.rep == null) {
        // Creating new rep
        await _repService.createRep(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          outletId: _selectedOutletId,
        );

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales representative account created successfully!',
                  ),
                  const SizedBox(height: 8),
                  Text('Name: ${_fullNameController.text}'),
                  Text('Email: ${_emailController.text}'),
                  if (_selectedOutletId != null)
                    Text(
                      'Outlet: ${_outlets.firstWhere((o) => o.id == _selectedOutletId).name}',
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(
                      context,
                    ).pop(true); // Return to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Updating existing rep
        final success = await _repService.updateRep(
          widget.rep!.copyWith(
            fullName: _fullNameController.text,
            email: _emailController.text,
            outletId: _selectedOutletId,
          ),
        );

        if (success) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Success'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales representative account updated successfully!',
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${_fullNameController.text}'),
                    Text('Email: ${_emailController.text}'),
                    if (_selectedOutletId != null)
                      Text(
                        'Outlet: ${_outlets.firstWhere((o) => o.id == _selectedOutletId).name}',
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(
                        context,
                      ).pop(true); // Return to previous screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update rep')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'An error occurred';
        if (e.toString().contains('User not allowed')) {
          errorMessage =
              'You do not have permission to create users. Please check your admin privileges.';
        } else if (e.toString().contains('already exists')) {
          errorMessage = 'A user with this email already exists.';
        }

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rep == null ? 'Add New Rep' : 'Edit Rep'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              if (widget.rep == null) // Only show password field for new reps
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required field' : null,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOutletId,
                decoration: const InputDecoration(labelText: 'Outlet'),
                items: _outlets.map((outlet) {
                  return DropdownMenuItem(
                    value: outlet.id,
                    child: Text(outlet.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOutletId = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select an outlet' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveRep,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.rep == null ? 'Create Rep' : 'Update Rep'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
