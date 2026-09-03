import 'package:flutter/material.dart';
import '../../domain/entities/invoice_template_config.dart';
import '../../data/storage/invoice_config_storage.dart';
import '../../domain/services/pdf/pdf_invoice_generator.dart';
import 'package:printing/printing.dart';

class InvoiceCustomizerScreen extends StatefulWidget {
  const InvoiceCustomizerScreen({super.key});

  @override
  State<InvoiceCustomizerScreen> createState() => _InvoiceCustomizerScreenState();
}

class _InvoiceCustomizerScreenState extends State<InvoiceCustomizerScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstController;
  late TextEditingController _taxController;
  late TextEditingController _currencyController;
  late TextEditingController _termsController;
  late TextEditingController _footerController;

  int _selectedColorHex = 0xFF2879FF;
  bool _isLoading = true;

  final List<int> _colorOptions = [
    0xFF2879FF, // Royal Blue
    0xFF28C76F, // Emerald Green
    0xFF7367F0, // Purple
    0xFF1E293B, // Dark Navy
    0xFFFF9F43, // Orange
    0xFFEA5455, // Red
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _gstController = TextEditingController();
    _taxController = TextEditingController();
    _currencyController = TextEditingController();
    _termsController = TextEditingController();
    _footerController = TextEditingController();

    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await InvoiceConfigStorage.loadConfig();
    setState(() {
      _nameController.text = config.businessName;
      _addressController.text = config.businessAddress;
      _phoneController.text = config.phone;
      _emailController.text = config.email;
      _gstController.text = config.gstNo;
      _taxController.text = config.taxPercentage.toString();
      _currencyController.text = config.currencySymbol;
      _termsController.text = config.termsAndConditions;
      _footerController.text = config.footerNote;
      _selectedColorHex = config.primaryColorHex;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _taxController.dispose();
    _currencyController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  InvoiceTemplateConfig _buildCurrentConfig() {
    return InvoiceTemplateConfig(
      businessName: _nameController.text.trim(),
      businessAddress: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      gstNo: _gstController.text.trim(),
      primaryColorHex: _selectedColorHex,
      taxPercentage: double.tryParse(_taxController.text.trim()) ?? 18.0,
      currencySymbol: _currencyController.text.trim(),
      termsAndConditions: _termsController.text.trim(),
      footerNote: _footerController.text.trim(),
    );
  }

  Future<void> _saveAndExit() async {
    if (!_formKey.currentState!.validate()) return;

    final config = _buildCurrentConfig();
    await InvoiceConfigStorage.saveConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice & PDF Template saved! Future shares will use this layout.'),
          backgroundColor: Color(0xFF28C76F),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _previewPdf() async {
    final config = _buildCurrentConfig();
    final sampleData = {
      'Party Name': 'Aman Sharma',
      'Item / Narration': 'Consulting & Software Development Services',
      'Amount (₹)': '15000',
      'Payment Mode': 'Bank/UPI',
      'Voucher Type': 'Sales',
    };

    final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdf(
      config: config,
      rowData: sampleData,
      rowIndex: 0,
    );

    if (mounted) {
      Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Invoice_Preview.pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Invoice Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF2879FF)),
            tooltip: 'Preview Sample PDF',
            onPressed: _previewPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2879FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2879FF).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF2879FF), size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Customize your Invoice format once. All future row PDF shares will instantly use this layout!',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section 1: Business Details
                    _buildSectionHeader('Business Information', Icons.business),
                    const SizedBox(height: 12),
                    _buildTextField(_nameController, 'Business / Company Name', 'e.g. Acme Traders Pvt Ltd'),
                    const SizedBox(height: 10),
                    _buildTextField(_addressController, 'Business Address', 'e.g. 101 Corporate Park, Mumbai', maxLines: 2),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_phoneController, 'Phone Number', '+91 98765 43210')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_emailController, 'Email', 'info@acme.com')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(_gstController, 'GSTIN / Tax Reg No.', 'e.g. 27ABCDE1234F1Z5'),

                    const SizedBox(height: 24),

                    // Section 2: Colors & Financials
                    _buildSectionHeader('Theme & Tax Settings', Icons.palette),
                    const SizedBox(height: 12),

                    // Color Picker Row
                    const Text('Invoice Header Color Theme:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: _colorOptions.map((colorHex) {
                        final isSelected = _selectedColorHex == colorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColorHex = colorHex),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(colorHex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(child: _buildTextField(_taxController, 'Tax / GST %', '18.0', isNumeric: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_currencyController, 'Currency Symbol', '₹')),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Terms & Footer
                    _buildSectionHeader('Footer & Terms', Icons.gavel),
                    const SizedBox(height: 12),
                    _buildTextField(_termsController, 'Terms & Conditions', '1. Subject to local jurisdiction...', maxLines: 3),
                    const SizedBox(height: 10),
                    _buildTextField(_footerController, 'Footer Note', 'Thank you for your business!'),

                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _saveAndExit,
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Save Layout & Format', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28C76F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2879FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
