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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rep == null ? 'Add New Rep' : 'Edit Rep'),
        elevation: 2,
      ),
      body: Container(
        color: Colors.grey[50],
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Form Header
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                widget.rep == null ? Icons.person_add : Icons.edit,
                                size: 48,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.rep == null ? 'Create New Representative' : 'Edit Representative',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.rep == null
                                    ? 'Fill in the details to create a new sales representative'
                                    : 'Update the details of this sales representative',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Full Name Field
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          colorScheme: colorScheme,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required field' : null,
                        ),
                        const SizedBox(height: 24),
                        
                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          colorScheme: colorScheme,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required field' : null,
                        ),
                        const SizedBox(height: 24),
                        
                        // Password Field (only for new reps)
                        if (widget.rep == null)
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            colorScheme: colorScheme,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required field' : null,
                          ),
                        if (widget.rep == null) const SizedBox(height: 24),
                        
                        // Outlet Dropdown
                        _buildDropdownField(
                          value: _selectedOutletId,
                          label: 'Assigned Outlet',
                          icon: Icons.store_outlined,
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
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(height: 40),
                        
                        // Submit Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveRep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.rep == null ? 'Create Rep' : 'Update Rep',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
    required ColorScheme colorScheme,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
      isExpanded: true,
      dropdownColor: Colors.white,
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
