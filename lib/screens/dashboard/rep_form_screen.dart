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
        final rep = await _repService.createRep(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          outletId: _selectedOutletId,
        );

        if (rep != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rep created successfully')),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create rep')),
            );
          }
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rep updated successfully')),
            );
            Navigator.pop(context, true);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
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
