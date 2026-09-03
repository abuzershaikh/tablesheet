import 'package:flutter/material.dart';
import '../../domain/entities/template_entity.dart';

// Finance
import 'finance/tally_accounting_template.dart';
import 'finance/invoice_template.dart';
import 'finance/budget_template.dart';
import 'finance/expense_tracker_template.dart';

// Inventory
import 'inventory/stock_management_template.dart';
import 'inventory/product_catalog_template.dart';

// HR
import 'hr/employee_directory_template.dart';
import 'hr/attendance_template.dart';

// Education
import 'education/student_marks_template.dart';
import 'education/class_schedule_template.dart';

// Sales
import 'sales/sales_tracker_template.dart';
import 'sales/customer_crm_template.dart';

// Project
import 'project/task_tracker_template.dart';
import 'project/project_planner_template.dart';

// Personal
import 'personal/todo_list_template.dart';
import 'personal/habit_tracker_template.dart';

/// Master registry of all template categories and their templates
class TemplateRegistry {
  TemplateRegistry._();

  static final List<TemplateCategory> allCategories = [
    // 💰 Finance
    TemplateCategory(
      id: 'finance',
      name: 'Finance',
      description: 'Invoices, budgets & expense tracking',
      icon: Icons.receipt_long,
      gradientColors: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
      templates: [
        tallyAccountingTemplate,
        invoiceTemplate,
        budgetTemplate,
        expenseTrackerTemplate,
      ],
    ),

    // 📦 Inventory
    TemplateCategory(
      id: 'inventory',
      name: 'Inventory',
      description: 'Stock management & product catalogs',
      icon: Icons.inventory_2,
      gradientColors: const [Color(0xFFE65100), Color(0xFFFFB74D)],
      templates: [
        stockManagementTemplate,
        productCatalogTemplate,
      ],
    ),

    // 👥 HR / People
    TemplateCategory(
      id: 'hr',
      name: 'HR / People',
      description: 'Employee records & attendance',
      icon: Icons.people,
      gradientColors: const [Color(0xFF6A1B9A), Color(0xFFCE93D8)],
      templates: [
        employeeDirectoryTemplate,
        attendanceTemplate,
      ],
    ),

    // 🎓 Education
    TemplateCategory(
      id: 'education',
      name: 'Education',
      description: 'Student marks & class schedules',
      icon: Icons.school,
      gradientColors: const [Color(0xFF2E7D32), Color(0xFF81C784)],
      templates: [
        studentMarksTemplate,
        classScheduleTemplate,
      ],
    ),

    // 📊 Sales & CRM
    TemplateCategory(
      id: 'sales',
      name: 'Sales & CRM',
      description: 'Sales tracking & customer management',
      icon: Icons.trending_up,
      gradientColors: const [Color(0xFFC62828), Color(0xFFEF9A9A)],
      templates: [
        salesTrackerTemplate,
        customerCrmTemplate,
      ],
    ),

    // 📋 Project
    TemplateCategory(
      id: 'project',
      name: 'Project',
      description: 'Task tracking & project planning',
      icon: Icons.assignment,
      gradientColors: const [Color(0xFF00695C), Color(0xFF80CBC4)],
      templates: [
        taskTrackerTemplate,
        projectPlannerTemplate,
      ],
    ),

    // 🏠 Personal
    TemplateCategory(
      id: 'personal',
      name: 'Personal',
      description: 'Todo lists & habit trackers',
      icon: Icons.person,
      gradientColors: const [Color(0xFF283593), Color(0xFF9FA8DA)],
      templates: [
        todoListTemplate,
        habitTrackerTemplate,
      ],
    ),
  ];

  /// Get all templates from all categories
  static List<SheetTemplate> get allTemplates =>
      allCategories.expand((c) => c.templates).toList();

  /// Find template by ID
  static SheetTemplate? findById(String id) {
    for (final category in allCategories) {
      for (final template in category.templates) {
        if (template.id == id) return template;
      }
    }
    return null;
  }

  /// Get category by ID
  static TemplateCategory? getCategoryById(String id) {
    try {
      return allCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
