# Requirements Document

## Introduction

This document specifies the requirements for a comprehensive Mobile Spreadsheet application for Android that provides Google Sheets-like functionality with high-performance Vulkan-accelerated rendering and GPU-accelerated computations. The application enables users to create, edit, and manage spreadsheets with extensive formatting, formula support, and smooth scrolling performance for large datasets.

## Glossary

- **Spreadsheet_App**: The mobile spreadsheet application system
- **Grid_Renderer**: The Vulkan-based GPU-accelerated rendering component for spreadsheet cells
- **Cell**: A single data unit in the spreadsheet grid identified by row and column coordinates
- **Formula_Engine**: The computation component that parses and evaluates spreadsheet formulas
- **Cell_Range**: A rectangular selection of cells identified by start and end coordinates
- **Sheet**: A single tab/page within a spreadsheet containing a grid of cells
- **Spreadsheet_Document**: A file containing one or more sheets with associated metadata
- **Storage_Manager**: The SQLite-based persistence layer for spreadsheet data
- **Format_Style**: Visual properties applied to cells including font, color, alignment, and borders
- **Virtual_Viewport**: The visible portion of the spreadsheet grid rendered on screen
- **Dependency_Graph**: A data structure tracking formula dependencies for recalculation ordering
- **Compute_Shader**: GPU program executing parallel calculations on cell data
- **Cell_Cache**: In-memory storage of recently accessed cell data for performance optimization
- **Custom_Render_Engine**: Specialized Vulkan-based graphics engine built for high-performance spreadsheet rendering
- **Virtual_Viewport**: The visible portion of the spreadsheet grid rendered on screen using custom engine
- **Cell_Batch_Renderer**: Component that renders multiple cells in a single GPU draw call for performance
- **Texture_Atlas**: Large 2048×2048 GPU texture containing pre-rendered text glyphs for fast text display
- **Command_Buffer_Pool**: Reusable Vulkan command buffers for efficient GPU command submission
- **GPU_Memory_Allocator**: Custom memory management system for efficient GPU resource allocation
- **Fill_Handle**: UI control allowing users to drag-copy cell values or formulas
- **Column_Header**: The labeled region at the top of the grid showing column identifiers (A, B, C...)
- **Row_Header**: The labeled region at the left of the grid showing row numbers (1, 2, 3...)
- **Column_Properties_Sheet**: Bottom sheet modal displaying column configuration options including name, type, width, and styling
- **Row_Properties_Sheet**: Bottom sheet modal displaying row configuration options including height and styling
- **FAB_Button**: Floating Action Button in the bottom-right corner of the home screen for quick actions
- **Sheet_Card**: Visual card component displaying spreadsheet preview and metadata on the home screen
- **Google_Forms_Connector**: Integration component that imports responses from Google Forms into spreadsheets
- **API_Connector**: Integration component that fetches data from REST APIs and imports into spreadsheets
- **AI_Agent_API**: Structured data access interface for AI agents to read and manipulate spreadsheet data
- **Sheet_UUID**: Universally unique identifier for a spreadsheet sheet
- **Row_UUID**: Universally unique identifier for a spreadsheet row, persistent across operations
- **Column_UUID**: Universally unique identifier for a spreadsheet column
- **Cell_UUID**: Universally unique identifier for a spreadsheet cell
- **API_Endpoint_Store**: Repository for saved REST API endpoint configurations
- **Form_Response_Sync**: Process that fetches new responses from Google Forms at intervals

## Requirements

### Requirement 1: File Management System

**User Story:** As a user, I want to manage my spreadsheet files, so that I can organize and access my work efficiently.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL display Sheet_Card components showing recently opened spreadsheet files on the home screen
2. WHEN a user taps a Sheet_Card, THE Spreadsheet_App SHALL open the corresponding spreadsheet within 1 second
3. WHEN a user long-presses a Sheet_Card, THE Spreadsheet_App SHALL enable multi-select mode
4. WHEN a user swipes a Sheet_Card, THE Spreadsheet_App SHALL display a delete action with undo capability
5. THE Spreadsheet_App SHALL display a FAB_Button in the bottom-right corner of the home screen
6. WHEN a user taps the FAB_Button, THE Spreadsheet_App SHALL display an action menu with options for creating and importing spreadsheets
7. WHEN a user selects Create New Sheet from the FAB menu, THE Spreadsheet_App SHALL create a blank spreadsheet document and open it for editing
8. WHEN a user selects Import from Excel from the FAB menu, THE Spreadsheet_App SHALL open a file picker for xlsx and xls files
9. WHEN a user selects Import from CSV from the FAB menu, THE Spreadsheet_App SHALL open a file picker for csv files
10. WHEN a user selects Import from Google Forms from the FAB menu, THE Spreadsheet_App SHALL initiate the Google Forms authentication flow
11. WHEN a user selects Import from API from the FAB menu, THE Spreadsheet_App SHALL open the API configuration dialog
12. THE Spreadsheet_App SHALL provide search functionality to filter Sheet_Card components by name
13. THE Spreadsheet_App SHALL allow sorting sheets by name, date modified, and date created
14. THE Spreadsheet_App SHALL support grid view with 2 columns and list view for Sheet_Card display
15. THE Spreadsheet_App SHALL toggle between grid view and list view when a user requests view change
16. WHEN a user requests to rename a file from the Sheet_Card menu, THE Spreadsheet_App SHALL update the file name and refresh the display
17. WHEN a user requests to delete a file from the Sheet_Card menu, THE Spreadsheet_App SHALL remove the file and update the display
18. WHEN a user requests to duplicate a file from the Sheet_Card menu, THE Spreadsheet_App SHALL create a copy with a unique name
19. THE Spreadsheet_App SHALL provide predefined templates including Blank, Budget, and Schedule

### Requirement 2: Grid Structure and Display

**User Story:** As a user, I want to work with a spreadsheet grid, so that I can organize data in rows and columns.

#### Acceptance Criteria

1. THE Grid_Renderer SHALL display cells arranged in rows numbered 1, 2, 3 and columns labeled A, B, C, AA, AB
2. THE Grid_Renderer SHALL initially provide 1000 rows and 26 columns for each sheet
3. WHEN a user scrolls beyond the current grid boundaries, THE Grid_Renderer SHALL expand the grid dynamically
4. THE Grid_Renderer SHALL support cell selection for single cells, rectangular ranges, and multiple non-contiguous ranges
5. WHEN a user selects a cell range, THE Grid_Renderer SHALL highlight the selected cells with a distinct border
6. THE Grid_Renderer SHALL display Column_Header and Row_Header with appropriate labels
7. WHEN a user taps a Column_Header, THE Spreadsheet_App SHALL display a bottom sheet with column properties editor
8. WHEN a user taps a Row_Header, THE Spreadsheet_App SHALL display a bottom sheet with row properties editor
9. WHEN a user drags a Column_Header border, THE Grid_Renderer SHALL resize the column width
10. WHEN a user drags a Row_Header border, THE Grid_Renderer SHALL resize the row height
11. WHEN a user double-clicks a Column_Header border, THE Grid_Renderer SHALL auto-fit the column width to content
12. WHEN a user requests to hide a row or column, THE Grid_Renderer SHALL hide the row or column from view
13. WHEN a user requests to unhide a row or column, THE Grid_Renderer SHALL restore the row or column to view
14. WHEN a user requests to insert rows or columns, THE Grid_Renderer SHALL insert the specified number at the selected position
15. WHEN a user requests to delete rows or columns, THE Grid_Renderer SHALL remove the specified rows or columns
16. WHEN a user requests to freeze rows or columns, THE Grid_Renderer SHALL keep the specified rows or columns fixed during scrolling

### Requirement 3: Cell Editing and Input

**User Story:** As a user, I want to edit cell content, so that I can enter and modify data.

#### Acceptance Criteria

1. WHEN a user taps a cell once, THE Spreadsheet_App SHALL select the cell
2. WHEN a user double-taps a cell, THE Spreadsheet_App SHALL activate in-cell editing mode with cursor
3. WHILE in-cell editing mode, THE Spreadsheet_App SHALL display a formula bar showing the cell content
4. WHEN a user types in the formula bar, THE Spreadsheet_App SHALL update the cell content in real-time
5. WHEN a user begins typing a function name, THE Spreadsheet_App SHALL display auto-complete suggestions for matching functions
6. WHEN a user presses Enter, THE Spreadsheet_App SHALL commit the cell content and move selection to the cell below
7. WHEN a user presses Tab, THE Spreadsheet_App SHALL commit the cell content and move selection to the cell to the right
8. WHEN a user presses Escape, THE Spreadsheet_App SHALL cancel editing and restore the original cell content

### Requirement 4: Cell Formatting

**User Story:** As a user, I want to format cells, so that I can improve readability and visual presentation.

#### Acceptance Criteria

1. WHEN a user applies bold formatting, THE Spreadsheet_App SHALL render the cell text in bold font weight
2. WHEN a user applies italic formatting, THE Spreadsheet_App SHALL render the cell text in italic font style
3. WHEN a user applies underline formatting, THE Spreadsheet_App SHALL render the cell text with underline decoration
4. WHEN a user selects a text color, THE Spreadsheet_App SHALL render the cell text in the selected color
5. WHEN a user selects a background color, THE Spreadsheet_App SHALL render the cell background in the selected color
6. WHEN a user selects left alignment, THE Spreadsheet_App SHALL align cell content to the left edge
7. WHEN a user selects center alignment, THE Spreadsheet_App SHALL align cell content to the horizontal center
8. WHEN a user selects right alignment, THE Spreadsheet_App SHALL align cell content to the right edge
9. WHEN a user selects top vertical alignment, THE Spreadsheet_App SHALL align cell content to the top edge
10. WHEN a user selects middle vertical alignment, THE Spreadsheet_App SHALL align cell content to the vertical center
11. WHEN a user selects bottom vertical alignment, THE Spreadsheet_App SHALL align cell content to the bottom edge
12. WHEN a user enables text wrapping, THE Spreadsheet_App SHALL wrap text to fit within the column width
13. WHEN a user applies a number format, THE Spreadsheet_App SHALL display numbers according to the format pattern (currency, percentage, date, custom)
14. WHEN a user merges selected cells, THE Spreadsheet_App SHALL combine the cells into a single merged cell
15. WHEN a user unmerges a merged cell, THE Spreadsheet_App SHALL restore the original cell boundaries

### Requirement 5: Data Persistence with SQLite

**User Story:** As a user, I want my spreadsheet data saved reliably, so that I can retrieve it without data loss.

#### Acceptance Criteria

1. THE Storage_Manager SHALL store spreadsheet metadata in a Spreadsheets table with columns for id, name, created_date, modified_date, thumbnail, and last_opened
2. THE Storage_Manager SHALL store sheet information in a Sheets table with columns for sheet_id as Sheet_UUID, spreadsheet_id, sheet_name, sheet_order, created_at, and modified_at
3. THE Storage_Manager SHALL store row information in a Rows table with columns for row_id as Row_UUID, sheet_id, row_number, and created_at
4. THE Storage_Manager SHALL store column information in a Columns table with columns for column_id as Column_UUID, sheet_id, column_name, column_number, column_type, and created_at
5. THE Storage_Manager SHALL store cell data in a Cells table with columns for cell_id as Cell_UUID, sheet_id, row_id as Row_UUID, column_id as Column_UUID, value, formula, data_type, format_json, created_at, and modified_at
6. THE Storage_Manager SHALL store API endpoint configurations in an API_Endpoints table with columns for endpoint_id, name, url, method, auth_type, auth_credentials, and last_sync
7. THE Storage_Manager SHALL store Google Forms configurations in a Google_Forms table with columns for form_id, form_title, sheet_id, last_sync, and auto_sync_enabled
8. THE Storage_Manager SHALL assign a unique Sheet_UUID to each sheet that remains constant throughout the sheet lifecycle
9. THE Storage_Manager SHALL assign a unique Row_UUID to each row that persists across insert and delete operations
10. THE Storage_Manager SHALL assign a unique Column_UUID to each column that persists across insert and delete operations
11. THE Storage_Manager SHALL assign a unique Cell_UUID to each cell
12. THE Storage_Manager SHALL store only non-empty cells to optimize storage space
13. THE Storage_Manager SHALL create an index on the Cells table columns (sheet_id, row_id, column_id) for query performance
14. WHEN a user modifies cell data, THE Storage_Manager SHALL batch updates and commit every 30 seconds
15. WHEN a user explicitly saves a spreadsheet, THE Storage_Manager SHALL immediately commit all pending changes
16. WHEN a user opens a spreadsheet, THE Storage_Manager SHALL load cell data lazily as the user scrolls
17. THE Storage_Manager SHALL maintain a Cell_Cache of frequently accessed cells in memory
18. WHEN cache memory exceeds 50 megabytes, THE Storage_Manager SHALL evict least recently used cells from the cache

### Requirement 6: Formula Parsing and Evaluation

**User Story:** As a user, I want to use formulas in cells, so that I can perform calculations on my data.

#### Acceptance Criteria

1. WHEN a user enters text beginning with an equals sign, THE Formula_Engine SHALL parse the text as a formula
2. THE Formula_Engine SHALL support basic arithmetic operators: addition, subtraction, multiplication, division, and exponentiation
3. THE Formula_Engine SHALL support cell references in the format A1, B2, AA10
4. THE Formula_Engine SHALL support cell range references in the format A1:B10
5. THE Formula_Engine SHALL evaluate formulas according to standard operator precedence
6. WHEN a formula contains a syntax error, THE Formula_Engine SHALL display an error indicator in the cell
7. WHEN a formula references another cell, THE Formula_Engine SHALL record the dependency in a Dependency_Graph
8. WHEN a referenced cell value changes, THE Formula_Engine SHALL recalculate all dependent formulas
9. IF a formula creates a circular reference, THEN THE Formula_Engine SHALL detect the cycle and display an error message
10. THE Formula_Engine SHALL complete typical formula calculations within 100 milliseconds

### Requirement 7: Built-in Functions Library

**User Story:** As a user, I want to use built-in functions, so that I can perform common calculations without writing complex formulas.

#### Acceptance Criteria

1. THE Formula_Engine SHALL support the SUM function to calculate the sum of a cell range
2. THE Formula_Engine SHALL support the AVERAGE function to calculate the arithmetic mean of a cell range
3. THE Formula_Engine SHALL support the COUNT function to count numeric values in a cell range
4. THE Formula_Engine SHALL support the MIN function to find the minimum value in a cell range
5. THE Formula_Engine SHALL support the MAX function to find the maximum value in a cell range
6. THE Formula_Engine SHALL support the ABS function to return the absolute value of a number
7. THE Formula_Engine SHALL support the ROUND function to round a number to a specified number of digits
8. THE Formula_Engine SHALL support the SQRT function to calculate the square root of a number
9. THE Formula_Engine SHALL support the POWER function to raise a number to a specified exponent
10. THE Formula_Engine SHALL support the MOD function to return the remainder of division
11. THE Formula_Engine SHALL support the CONCATENATE function to join text strings
12. THE Formula_Engine SHALL support the LEFT function to extract characters from the beginning of text
13. THE Formula_Engine SHALL support the RIGHT function to extract characters from the end of text
14. THE Formula_Engine SHALL support the MID function to extract characters from the middle of text
15. THE Formula_Engine SHALL support the LEN function to return the length of text
16. THE Formula_Engine SHALL support the UPPER function to convert text to uppercase
17. THE Formula_Engine SHALL support the LOWER function to convert text to lowercase
18. THE Formula_Engine SHALL support the IF function to return values based on a logical condition
19. THE Formula_Engine SHALL support the AND function to evaluate multiple conditions with logical AND
20. THE Formula_Engine SHALL support the OR function to evaluate multiple conditions with logical OR
21. THE Formula_Engine SHALL support the NOT function to negate a logical value
22. THE Formula_Engine SHALL support the TODAY function to return the current date
23. THE Formula_Engine SHALL support the NOW function to return the current date and time
24. THE Formula_Engine SHALL support the DATE function to create a date from year, month, and day values
25. THE Formula_Engine SHALL support the YEAR function to extract the year from a date
26. THE Formula_Engine SHALL support the MONTH function to extract the month from a date
27. THE Formula_Engine SHALL support the DAY function to extract the day from a date
28. THE Formula_Engine SHALL support the VLOOKUP function to search a vertical lookup table
29. THE Formula_Engine SHALL support the HLOOKUP function to search a horizontal lookup table
30. THE Formula_Engine SHALL support the INDEX function to return a value from a specified position
31. THE Formula_Engine SHALL support the MATCH function to find the position of a value in a range

### Requirement 8: Vulkan-Accelerated Rendering with Custom Engine

**User Story:** As a user, I want smooth scrolling performance, so that I can navigate large spreadsheets efficiently.

#### Acceptance Criteria

1. WHERE Vulkan is supported, THE Grid_Renderer SHALL initialize a custom Vulkan rendering engine at application startup
2. THE Custom_Render_Engine SHALL create Vulkan instance, select physical GPU device, and configure graphics and compute queues
3. THE Custom_Render_Engine SHALL implement Virtual_Viewport system to render only visible cells
4. THE Custom_Render_Engine SHALL calculate visible cell range based on scroll position and viewport dimensions
5. THE Custom_Render_Engine SHALL pre-render cells adjacent to viewport for smooth scrolling transitions
6. THE Cell_Batch_Renderer SHALL render multiple cells in a single GPU draw call using instance rendering
7. THE Cell_Batch_Renderer SHALL prepare instance data including position, size, colors, and texture indices for all visible cells
8. THE Custom_Render_Engine SHALL use Texture_Atlas system for text rendering with 2048×2048 GPU texture
9. THE Texture_Atlas SHALL cache pre-rendered text glyphs for numbers, letters, and common text patterns
10. THE Custom_Render_Engine SHALL render grid lines using fragment shaders without geometry for optimal performance
11. THE Grid_Renderer SHALL maintain a minimum frame rate of 60 frames per second during scrolling
12. THE Grid_Renderer SHALL achieve 120 frames per second on devices with high refresh rate displays
13. WHEN a user scrolls the spreadsheet, THE Grid_Renderer SHALL update the Virtual_Viewport within 16 milliseconds
14. THE Custom_Render_Engine SHALL implement Command_Buffer_Pool for reusing Vulkan command buffers across frames
15. THE Custom_Render_Engine SHALL implement descriptor set pooling for efficient GPU resource management
16. THE GPU_Memory_Allocator SHALL manage GPU memory allocation with memory aliasing for optimal usage
17. THE Custom_Render_Engine SHALL use asynchronous transfer queue for uploading data without blocking rendering
18. THE Custom_Render_Engine SHALL allocate approximately 41 megabytes of GPU memory for rendering resources
19. WHERE Vulkan is not supported, THE Grid_Renderer SHALL fall back to CPU-based rendering using Flutter canvas
20. WHEN falling back to CPU rendering, THE Grid_Renderer SHALL display a notification to the user
21. THE Grid_Renderer SHALL support pinch-to-zoom gestures for adjusting zoom level from 0.5x to 3.0x
22. WHEN a user performs a pinch-to-zoom gesture, THE Grid_Renderer SHALL scale the grid smoothly without stuttering
23. THE Custom_Render_Engine SHALL provide JNI interface methods for Flutter to Dart communication
24. THE Custom_Render_Engine SHALL achieve 10x faster cell rendering compared to CPU-only rendering
25. THE Custom_Render_Engine SHALL reduce battery consumption by 40-50 percent compared to CPU rendering

### Requirement 9: GPU-Accelerated Calculations with Custom Compute Engine

**User Story:** As a user, I want fast calculation performance, so that I can work with large datasets efficiently.

#### Acceptance Criteria

1. WHERE Vulkan compute capability is available, THE Formula_Engine SHALL use custom GPU compute system for bulk calculations
2. THE Formula_Engine SHALL implement Formula_Compiler that converts spreadsheet formulas to GLSL compute shader code
3. THE Formula_Compiler SHALL generate SPIR-V shader modules from formula abstract syntax tree
4. THE Formula_Engine SHALL support parallel reduction algorithms for aggregate functions like SUM and AVERAGE
5. WHERE Vulkan compute capability is available AND a formula range exceeds 1000 cells, THE Formula_Engine SHALL execute the calculation on the GPU
6. WHEN calculating SUM over a range, THE Formula_Engine SHALL use GPU compute shaders with work group size of 32
7. WHEN calculating AVERAGE over a range, THE Formula_Engine SHALL use GPU parallel reduction with shared memory optimization
8. THE Formula_Engine SHALL create SSBO (Shader Storage Buffer Objects) for input and output data
9. THE Formula_Engine SHALL dispatch compute shaders with appropriate work group counts based on data size
10. THE Formula_Engine SHALL support batch execution of multiple formulas in parallel on GPU
11. THE Formula_Engine SHALL implement asynchronous formula execution without blocking UI thread
12. WHERE GPU calculation is not available, THE Formula_Engine SHALL execute calculations on the CPU
13. THE Formula_Engine SHALL complete calculation of SUM over 10000 cells within 5 milliseconds using GPU acceleration
14. THE Formula_Engine SHALL complete calculation of AVERAGE over 10000 cells within 5 milliseconds using GPU acceleration
15. THE Formula_Engine SHALL complete matrix multiplication (100×100) within 20 milliseconds using GPU acceleration
16. THE Formula_Engine SHALL complete complex formulas within 15 milliseconds using GPU acceleration
17. THE Formula_Engine SHALL achieve 10x speedup for SUM calculations compared to CPU execution
18. THE Formula_Engine SHALL achieve 13x speedup for complex formulas compared to CPU execution
19. THE Formula_Engine SHALL achieve 25x speedup for matrix operations compared to CPU execution

### Requirement 10: Multi-Sheet Management

**User Story:** As a user, I want to work with multiple sheets in a spreadsheet, so that I can organize related data separately.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL display sheet tabs at the bottom of the screen
2. WHEN a user taps a sheet tab, THE Spreadsheet_App SHALL switch to the selected sheet
3. WHEN a user requests to add a new sheet, THE Spreadsheet_App SHALL create a new sheet with a default name and add it to the tab bar
4. WHEN a user requests to delete a sheet, THE Spreadsheet_App SHALL remove the sheet and all its data
5. WHEN a user requests to rename a sheet, THE Spreadsheet_App SHALL update the sheet name in the tab bar
6. WHEN a user drags a sheet tab, THE Spreadsheet_App SHALL reorder the sheets according to the new position
7. WHEN a user requests to duplicate a sheet, THE Spreadsheet_App SHALL create a copy of the sheet with all data and formatting
8. THE Spreadsheet_App SHALL support a minimum of 50 sheets per spreadsheet document

### Requirement 11: Copy, Cut, and Paste Operations

**User Story:** As a user, I want to copy and move data, so that I can efficiently duplicate and reorganize information.

#### Acceptance Criteria

1. WHEN a user selects cells and requests Copy, THE Spreadsheet_App SHALL copy the cell values and formatting to the clipboard
2. WHEN a user selects cells and requests Cut, THE Spreadsheet_App SHALL copy the cell data to the clipboard and mark cells for deletion
3. WHEN a user requests Paste, THE Spreadsheet_App SHALL insert the clipboard content at the current selection
4. WHEN pasting cells with formulas, THE Spreadsheet_App SHALL adjust cell references relative to the new position
5. WHEN a user requests Paste Special with values only, THE Spreadsheet_App SHALL paste only the cell values without formatting or formulas
6. WHEN a user requests Paste Special with formatting only, THE Spreadsheet_App SHALL apply the copied formatting without changing cell values

### Requirement 12: Fill Handle and Auto-Fill

**User Story:** As a user, I want to quickly fill adjacent cells with patterns, so that I can efficiently enter sequential data.

#### Acceptance Criteria

1. WHEN a user selects a cell, THE Spreadsheet_App SHALL display a Fill_Handle at the bottom-right corner of the selection
2. WHEN a user drags the Fill_Handle down or right, THE Spreadsheet_App SHALL fill the target cells with copied values or extended patterns
3. WHEN a cell contains a number and the Fill_Handle is dragged, THE Spreadsheet_App SHALL increment the number in a linear sequence
4. WHEN a cell contains a date and the Fill_Handle is dragged, THE Spreadsheet_App SHALL increment the date by day
5. WHEN a cell contains a formula and the Fill_Handle is dragged, THE Spreadsheet_App SHALL copy the formula with adjusted cell references
6. WHEN consecutive selected cells contain a numeric pattern, THE Spreadsheet_App SHALL detect and extend the pattern when the Fill_Handle is dragged

### Requirement 13: Find and Replace

**User Story:** As a user, I want to find and replace text, so that I can quickly update data throughout the spreadsheet.

#### Acceptance Criteria

1. WHEN a user opens the Find dialog, THE Spreadsheet_App SHALL provide a search input field
2. WHEN a user enters search text and requests Find Next, THE Spreadsheet_App SHALL navigate to the next cell containing the search text
3. WHEN a user enters search text and requests Find All, THE Spreadsheet_App SHALL highlight all cells containing the search text
4. WHEN a user opens the Replace dialog, THE Spreadsheet_App SHALL provide search and replacement input fields
5. WHEN a user requests Replace, THE Spreadsheet_App SHALL replace the current match with the replacement text
6. WHEN a user requests Replace All, THE Spreadsheet_App SHALL replace all occurrences of the search text with the replacement text
7. THE Spreadsheet_App SHALL support case-sensitive and case-insensitive search options
8. THE Spreadsheet_App SHALL support matching whole cells or partial content

### Requirement 14: Sorting and Filtering

**User Story:** As a user, I want to sort and filter data, so that I can analyze information more effectively.

#### Acceptance Criteria

1. WHEN a user selects a column and requests sort ascending, THE Spreadsheet_App SHALL sort the data in ascending order
2. WHEN a user selects a column and requests sort descending, THE Spreadsheet_App SHALL sort the data in descending order
3. WHEN sorting, THE Spreadsheet_App SHALL move entire rows to maintain data integrity across columns
4. WHEN a user enables filtering on a column, THE Spreadsheet_App SHALL display a filter dropdown in the column header
5. WHEN a user selects filter criteria, THE Spreadsheet_App SHALL hide rows that do not match the criteria
6. WHEN a user clears filters, THE Spreadsheet_App SHALL restore all hidden rows to view
7. THE Spreadsheet_App SHALL support multiple active filters across different columns simultaneously

### Requirement 15: Data Validation

**User Story:** As a user, I want to restrict cell input to valid values, so that I can maintain data quality.

#### Acceptance Criteria

1. WHEN a user applies data validation to a cell, THE Spreadsheet_App SHALL define allowed input criteria
2. WHEN a user enters data in a validated cell, THE Spreadsheet_App SHALL check the input against the validation criteria
3. IF input violates validation criteria, THEN THE Spreadsheet_App SHALL display an error message and reject the input
4. THE Spreadsheet_App SHALL support validation types including number range, list of values, date range, and custom formula
5. WHEN validation type is list of values, THE Spreadsheet_App SHALL display a dropdown selector in the cell
6. THE Spreadsheet_App SHALL allow users to specify custom error messages for validation failures

### Requirement 16: Conditional Formatting

**User Story:** As a user, I want to automatically format cells based on their values, so that I can visually identify important data.

#### Acceptance Criteria

1. WHEN a user applies conditional formatting, THE Spreadsheet_App SHALL define formatting rules based on cell values
2. WHEN a cell value matches a conditional formatting rule, THE Spreadsheet_App SHALL apply the specified format style
3. THE Spreadsheet_App SHALL support conditional formatting rules including greater than, less than, between, equal to, and custom formula
4. THE Spreadsheet_App SHALL support formatting actions including background color, text color, and bold
5. WHEN multiple conditional formatting rules apply to a cell, THE Spreadsheet_App SHALL apply the highest priority rule
6. WHEN a cell value changes, THE Spreadsheet_App SHALL re-evaluate and update conditional formatting immediately

### Requirement 17: Basic Charts

**User Story:** As a user, I want to create charts from data, so that I can visualize trends and patterns.

#### Acceptance Criteria

1. WHEN a user selects a data range and requests to create a chart, THE Spreadsheet_App SHALL display chart type options
2. THE Spreadsheet_App SHALL support line chart, bar chart, and pie chart types
3. WHEN a user selects a chart type, THE Spreadsheet_App SHALL generate the chart using the selected data
4. THE Spreadsheet_App SHALL display the chart as an overlay on the spreadsheet
5. WHEN the source data changes, THE Spreadsheet_App SHALL update the chart automatically
6. WHEN a user taps a chart, THE Spreadsheet_App SHALL allow editing of chart properties including title, colors, and axis labels
7. WHEN a user drags a chart, THE Spreadsheet_App SHALL reposition the chart on the grid

### Requirement 18: Import and Export

**User Story:** As a user, I want to import and export files, so that I can share data with other applications.

#### Acceptance Criteria

1. WHEN a user requests to import a CSV file, THE Spreadsheet_App SHALL parse the CSV and create a new sheet with the data
2. WHEN a user requests to import an Excel file, THE Spreadsheet_App SHALL parse the Excel format and create sheets with data and basic formatting
3. WHEN a user requests to import from Google Forms, THE Google_Forms_Connector SHALL authenticate the user with OAuth 2.0
4. WHEN Google Forms authentication succeeds, THE Google_Forms_Connector SHALL display a list of available forms
5. WHEN a user selects a Google Form, THE Google_Forms_Connector SHALL fetch form responses and map fields to spreadsheet columns
6. WHEN importing Google Forms data, THE Spreadsheet_App SHALL include response metadata including timestamp and email
7. WHEN a user enables real-time sync for a Google Form, THE Form_Response_Sync SHALL fetch new responses every 15 minutes
8. WHEN a user requests to import from API, THE API_Connector SHALL display a configuration dialog for REST API endpoint details
9. WHEN a user enters API endpoint URL and authentication credentials, THE API_Connector SHALL send a GET request to the endpoint
10. WHEN the API returns JSON data, THE API_Connector SHALL parse the response and display a field mapping interface
11. WHEN the API returns XML data, THE API_Connector SHALL parse the response and display a field mapping interface
12. WHEN a user maps API fields to columns, THE API_Connector SHALL create a new sheet with the imported data
13. WHEN a user saves an API endpoint configuration, THE API_Endpoint_Store SHALL store the configuration for future use
14. WHEN a user enables auto-refresh for an API endpoint, THE API_Connector SHALL fetch updated data at the specified interval
15. WHEN a user requests to export to CSV, THE Spreadsheet_App SHALL write the current sheet data in CSV format
16. WHEN a user requests to export to Excel, THE Spreadsheet_App SHALL write the spreadsheet data in Excel format with basic formatting preserved
17. WHEN importing data, THE Spreadsheet_App SHALL display a preview before creating the spreadsheet
18. IF an import operation fails, THEN THE Spreadsheet_App SHALL display an error message with the failure reason

### Requirement 19: Auto-Save and Offline Support

**User Story:** As a user, I want my work saved automatically, so that I don't lose data if the app closes unexpectedly.

#### Acceptance Criteria

1. WHILE a user is editing a spreadsheet, THE Spreadsheet_App SHALL automatically save changes every 30 seconds
2. WHEN a user makes a change, THE Spreadsheet_App SHALL mark the document as having unsaved changes
3. WHEN auto-save completes, THE Spreadsheet_App SHALL clear the unsaved changes indicator
4. THE Spreadsheet_App SHALL perform auto-save operations without blocking user interaction
5. THE Spreadsheet_App SHALL function fully offline using local SQLite storage
6. WHEN the app is closed during unsaved changes, THE Spreadsheet_App SHALL save all pending changes before terminating

### Requirement 20: Undo and Redo

**User Story:** As a user, I want to undo and redo actions, so that I can correct mistakes and explore alternatives.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL maintain a history of user actions including cell edits, formatting changes, and row/column operations
2. WHEN a user requests Undo, THE Spreadsheet_App SHALL revert the most recent action and update the display
3. WHEN a user requests Redo, THE Spreadsheet_App SHALL reapply the most recently undone action
4. THE Spreadsheet_App SHALL support a minimum of 50 undo/redo operations
5. WHEN a user performs a new action after undo, THE Spreadsheet_App SHALL clear the redo history
6. THE Spreadsheet_App SHALL include undo/redo buttons in the toolbar with appropriate enabled/disabled states

### Requirement 21: Performance Requirements

**User Story:** As a user, I want fast application performance, so that I can work efficiently without delays.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL launch within 2 seconds from tap to first screen display
2. WHEN a user opens a spreadsheet document, THE Spreadsheet_App SHALL display the spreadsheet within 1 second
3. THE Grid_Renderer SHALL maintain 60 frames per second during scrolling for sheets up to 10000 rows
4. THE Grid_Renderer SHALL support rendering sheets with 100000 or more cells without crashing
5. THE Formula_Engine SHALL complete typical formula calculations within 100 milliseconds
6. THE Spreadsheet_App SHALL perform auto-save operations without visible lag or frame drops
7. WHERE GPU acceleration is available, THE Grid_Renderer SHALL reduce battery consumption by 40 percent compared to CPU-only rendering

### Requirement 22: User Interface and Material Design

**User Story:** As a user, I want an intuitive interface, so that I can easily access features and navigate the application.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL implement Material Design 3 visual guidelines
2. THE Spreadsheet_App SHALL display a top app bar with blue primary color background (#1976D2)
3. THE top app bar SHALL include a back button, sheet title with badge, search icon, and more options menu
4. THE sheet title badge SHALL display sheet count or row count in parentheses
5. THE Spreadsheet_App SHALL display column headers in a fixed row below the app bar with light gray background (#F5F5F5)
6. THE column headers row SHALL include a menu icon on the left and add column button (+) on the right
7. THE Spreadsheet_App SHALL display row numbers in a fixed column on the left with 48dp width
8. THE row header column SHALL include an add row button (+) at the bottom-left corner with blue background
9. THE Spreadsheet_App SHALL display grid cells with default size 120dp width × 52dp height
10. WHEN a user selects a cell, THE Spreadsheet_App SHALL highlight it with light blue background (#E3F2FD) and blue border
11. WHEN a user enters edit mode, THE Spreadsheet_App SHALL show green border (#4CAF50) and display formula bar
12. THE formula bar SHALL appear below column headers when a cell is selected, showing fx icon, input field, and confirm/cancel buttons
13. THE Spreadsheet_App SHALL display sheet tabs above the bottom toolbar with active sheet indicated by blue underline
14. THE Spreadsheet_App SHALL display a bottom toolbar with 56dp height containing sort, filter, format, share, and more icons
15. THE Spreadsheet_App SHALL provide a context menu on long-press with options for cut, copy, paste, delete, format, and more
16. THE Spreadsheet_App SHALL use consistent iconography and color scheme throughout the interface
17. THE Spreadsheet_App SHALL provide visual feedback for all user interactions including taps, drags, and selections
18. THE Spreadsheet_App SHALL support both light and dark themes based on system settings
19. THE Spreadsheet_App SHALL use elevation and shadows for layered components following Material Design guidelines
20. THE Spreadsheet_App SHALL display fill handle as 6×6dp blue square at bottom-right corner of selected cell
21. WHEN a user drags the fill handle, THE Spreadsheet_App SHALL auto-fill cells with pattern or copy values
22. THE Spreadsheet_App SHALL maintain minimum touch target size of 48×48dp for all interactive elements

### Requirement 23: Sharing and Collaboration

**User Story:** As a user, I want to share spreadsheets, so that I can collaborate with others.

#### Acceptance Criteria

1. WHEN a user requests to share a spreadsheet, THE Spreadsheet_App SHALL display sharing options including link and email
2. WHEN a user selects share via link, THE Spreadsheet_App SHALL generate a shareable file URI
3. WHEN a user selects share via email, THE Spreadsheet_App SHALL open the email application with the spreadsheet attached
4. THE Spreadsheet_App SHALL support exporting the spreadsheet as a PDF for sharing
5. WHEN exporting to PDF, THE Spreadsheet_App SHALL maintain cell formatting and layout

### Requirement 24: Configuration File Parser and Pretty Printer

**User Story:** As a developer, I want to parse and format configuration files, so that I can reliably save and load application settings.

#### Acceptance Criteria

1. WHEN the Spreadsheet_App reads a configuration file, THE Config_Parser SHALL parse it into a Configuration object
2. IF a configuration file contains invalid syntax, THEN THE Config_Parser SHALL return a descriptive error message
3. THE Config_Pretty_Printer SHALL format Configuration objects into valid configuration file text
4. FOR ALL valid Configuration objects, parsing then printing then parsing SHALL produce an equivalent Configuration object (round-trip property)

### Requirement 25: Spreadsheet File Format Parser and Pretty Printer

**User Story:** As a developer, I want to parse and serialize spreadsheet file formats, so that I can implement import and export functionality reliably.

#### Acceptance Criteria

1. WHEN the Spreadsheet_App reads a CSV file, THE CSV_Parser SHALL parse it according to RFC 4180 specification
2. IF a CSV file contains malformed data, THEN THE CSV_Parser SHALL return descriptive error information
3. THE CSV_Pretty_Printer SHALL format spreadsheet data into valid CSV format according to RFC 4180
4. FOR ALL valid CSV data, parsing then printing then parsing SHALL produce equivalent data (round-trip property)
5. WHEN the Spreadsheet_App reads an Excel file, THE Excel_Parser SHALL parse basic Excel format including cell values and formatting
6. THE Excel_Pretty_Printer SHALL serialize spreadsheet data into valid Excel format
7. FOR ALL valid Excel data with supported features, parsing then printing then parsing SHALL preserve cell values and basic formatting (round-trip property)

### Requirement 26: FAB Button and Action Menu

**User Story:** As a user, I want quick access to create and import actions, so that I can efficiently start working with spreadsheets.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL display a FAB_Button in the bottom-right corner of the home screen
2. THE FAB_Button SHALL follow Material Design 3 specifications with elevation and animation
3. WHEN a user taps the FAB_Button, THE Spreadsheet_App SHALL display a speed dial menu with action options
4. THE FAB_Button menu SHALL include Create New Sheet option with a document icon
5. THE FAB_Button menu SHALL include Import from Excel option with an Excel icon
6. THE FAB_Button menu SHALL include Import from CSV option with a table icon
7. THE FAB_Button menu SHALL include Import from Google Forms option with a form icon
8. THE FAB_Button menu SHALL include Import from API option with a cloud icon
9. WHEN the speed dial menu opens, THE Spreadsheet_App SHALL animate the menu items with staggered timing
10. WHEN a user taps outside the speed dial menu, THE Spreadsheet_App SHALL close the menu
11. WHEN a user selects an action from the menu, THE Spreadsheet_App SHALL close the menu and execute the selected action

### Requirement 27: Sheet Preview Cards with Quick Actions

**User Story:** As a user, I want to see sheet previews and access quick actions, so that I can manage my spreadsheets efficiently.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL display spreadsheets as Sheet_Card components on the home screen
2. THE Sheet_Card SHALL display a thumbnail preview showing the first 5 rows and 5 columns of the sheet
3. THE Sheet_Card SHALL display the sheet name with a maximum of 2 lines with ellipsis for overflow
4. THE Sheet_Card SHALL display the last modified date and time in relative format
5. THE Sheet_Card SHALL display the file size in human-readable format
6. THE Sheet_Card SHALL display a row count and column count indicator
7. THE Sheet_Card SHALL include a three-dot menu button for quick actions
8. WHEN a user taps the three-dot menu, THE Spreadsheet_App SHALL display options for Open, Rename, Delete, Duplicate, and Share
9. WHEN a user taps the Sheet_Card body, THE Spreadsheet_App SHALL open the spreadsheet in the editor
10. WHEN a user long-presses a Sheet_Card, THE Spreadsheet_App SHALL enable multi-select mode with checkboxes
11. WHILE multi-select mode is active, THE Spreadsheet_App SHALL display a bottom action bar with batch operations
12. WHEN a user swipes a Sheet_Card to the left, THE Spreadsheet_App SHALL reveal a delete action
13. WHEN a user confirms swipe delete, THE Spreadsheet_App SHALL delete the sheet and display an undo snackbar for 5 seconds
14. WHEN a user taps undo within 5 seconds, THE Spreadsheet_App SHALL restore the deleted sheet
15. THE Spreadsheet_App SHALL display Sheet_Card components in a 2-column grid layout in grid view mode
16. THE Spreadsheet_App SHALL display Sheet_Card components in a single-column list layout in list view mode

### Requirement 28: Google Forms Integration

**User Story:** As a user, I want to import data from Google Forms, so that I can analyze form responses in a spreadsheet.

#### Acceptance Criteria

1. WHEN a user initiates Google Forms import, THE Google_Forms_Connector SHALL request OAuth 2.0 authentication
2. THE Google_Forms_Connector SHALL request permissions for reading Google Forms and responses
3. WHEN authentication succeeds, THE Google_Forms_Connector SHALL fetch the list of forms accessible to the user
4. WHEN a user selects a form, THE Google_Forms_Connector SHALL retrieve all form responses
5. THE Google_Forms_Connector SHALL map form field names to spreadsheet column headers
6. THE Google_Forms_Connector SHALL import response metadata including timestamp, responder email, and response ID
7. THE Google_Forms_Connector SHALL support multiple choice questions by importing selected options as text
8. THE Google_Forms_Connector SHALL support checkbox questions by importing multiple selections as comma-separated values
9. THE Google_Forms_Connector SHALL support text questions by importing responses as plain text
10. THE Google_Forms_Connector SHALL support rating questions by importing numeric ratings
11. WHEN a user enables real-time sync, THE Form_Response_Sync SHALL store the form ID for periodic fetching
12. WHILE real-time sync is enabled, THE Form_Response_Sync SHALL check for new responses every 15 minutes
13. WHEN new responses are detected, THE Form_Response_Sync SHALL append the new rows to the spreadsheet
14. THE Google_Forms_Connector SHALL display sync status including last sync time and response count
15. WHEN a user disables real-time sync, THE Form_Response_Sync SHALL stop periodic fetching for that form

### Requirement 29: REST API Data Import

**User Story:** As a user, I want to import data from REST APIs, so that I can integrate external data sources into my spreadsheets.

#### Acceptance Criteria

1. WHEN a user initiates API import, THE API_Connector SHALL display a configuration dialog
2. THE API_Connector configuration dialog SHALL include fields for endpoint URL, HTTP method, and authentication type
3. THE API_Connector SHALL support GET requests with query parameters
4. THE API_Connector SHALL support authentication types including None, API Key, Bearer Token, and Basic Auth
5. WHEN authentication type is API Key, THE API_Connector SHALL provide fields for key name and key value
6. WHEN authentication type is Bearer Token, THE API_Connector SHALL provide a field for the token value
7. WHEN authentication type is Basic Auth, THE API_Connector SHALL provide fields for username and password
8. WHEN a user tests the API connection, THE API_Connector SHALL send a request and display the response status
9. WHEN the API returns JSON data, THE API_Connector SHALL parse the JSON and extract field names
10. WHEN the API returns XML data, THE API_Connector SHALL parse the XML and extract element names
11. THE API_Connector SHALL display a field mapping interface showing API fields and target column names
12. WHEN a user completes field mapping, THE API_Connector SHALL create a new sheet and import the data
13. WHEN a user saves the API configuration, THE API_Endpoint_Store SHALL store the endpoint details including URL and authentication
14. WHEN a user loads a saved API configuration, THE API_Connector SHALL populate the configuration dialog with stored values
15. WHEN a user enables auto-refresh, THE API_Connector SHALL allow setting a refresh interval in minutes
16. WHILE auto-refresh is enabled, THE API_Connector SHALL fetch updated data at the specified interval
17. THE API_Connector SHALL maintain a history of API responses with timestamps
18. WHEN an API request fails, THE API_Connector SHALL display an error message with the HTTP status code and error details

### Requirement 30: AI Agent Data Access API

**User Story:** As an AI agent developer, I want structured access to spreadsheet data, so that I can enable AI agents to read and manipulate spreadsheets programmatically.

#### Acceptance Criteria

1. THE AI_Agent_API SHALL provide a getCellValue method accepting sheet_id as Sheet_UUID, row_id as Row_UUID, and column_id as Column_UUID returning the cell value
2. THE AI_Agent_API SHALL provide a setCellValue method accepting sheet_id, row_id, column_id, and value to update a cell
3. THE AI_Agent_API SHALL provide a getRowData method accepting sheet_id and row_id returning the entire row as a JSON object
4. THE AI_Agent_API SHALL provide a getColumnData method accepting sheet_id and column_id returning the entire column as a JSON array
5. THE AI_Agent_API SHALL provide a getRangeData method accepting sheet_id, start_row, start_col, end_row, and end_col returning a 2D array
6. THE AI_Agent_API SHALL provide an appendRow method accepting sheet_id and row_data as JSON to add a new row at the end
7. THE AI_Agent_API SHALL provide an updateRow method accepting sheet_id, row_id, and row_data as JSON to update an entire row
8. THE AI_Agent_API SHALL provide a deleteRow method accepting sheet_id and row_id to remove a row
9. THE AI_Agent_API SHALL provide a queryData method accepting sheet_id and filter_criteria to search cells matching conditions
10. THE AI_Agent_API SHALL provide a getSheetStructure method returning column names, column types, and column count
11. THE AI_Agent_API SHALL detect data types per column including text, number, date, and formula
12. THE AI_Agent_API SHALL provide a getFormulaDependencies method returning a graph of formula dependencies for a sheet
13. THE AI_Agent_API SHALL provide a getCellFormatting method returning formatting information including font, color, and alignment
14. THE AI_Agent_API SHALL provide a getValidationRules method returning data validation rules for a cell or column
15. WHEN an AI_Agent_API method receives an invalid Sheet_UUID, THE AI_Agent_API SHALL return an error indicating the sheet does not exist
16. WHEN an AI_Agent_API method receives an invalid Row_UUID or Column_UUID, THE AI_Agent_API SHALL return an error indicating the identifier is invalid
17. THE AI_Agent_API SHALL complete read operations within 50 milliseconds for typical datasets
18. THE AI_Agent_API SHALL complete write operations within 100 milliseconds for typical updates

### Requirement 31: Unique ID System for Cells, Rows, and Columns

**User Story:** As a developer, I want persistent unique identifiers for cells, rows, and columns, so that I can reliably reference spreadsheet elements across operations.

#### Acceptance Criteria

1. THE Storage_Manager SHALL assign a Sheet_UUID to each sheet using UUID version 4 format
2. THE Storage_Manager SHALL assign a Row_UUID to each row using UUID version 4 format
3. THE Storage_Manager SHALL assign a Column_UUID to each column using UUID version 4 format
4. THE Storage_Manager SHALL assign a Cell_UUID to each cell using UUID version 4 format
5. THE Storage_Manager SHALL construct cell addresses in the format {sheet_id}:{row_id}:{column_id}
6. WHEN a user inserts a new row, THE Storage_Manager SHALL assign a new Row_UUID and update row_number for affected rows
7. WHEN a user deletes a row, THE Storage_Manager SHALL preserve Row_UUID for remaining rows and update row_number values
8. WHEN a user inserts a new column, THE Storage_Manager SHALL assign a new Column_UUID and update column_number for affected columns
9. WHEN a user deletes a column, THE Storage_Manager SHALL preserve Column_UUID for remaining columns and update column_number values
10. THE Storage_Manager SHALL never reuse or reassign Sheet_UUID, Row_UUID, Column_UUID, or Cell_UUID values
11. THE Storage_Manager SHALL create database indexes on Sheet_UUID, Row_UUID, and Column_UUID for query performance
12. WHEN querying cells, THE Storage_Manager SHALL use UUID-based lookups rather than row and column numbers
13. THE Storage_Manager SHALL maintain a mapping between display coordinates (A1, B2) and UUID-based identifiers
14. WHEN a formula references a cell, THE Storage_Manager SHALL store the reference using Row_UUID and Column_UUID

### Requirement 32: Modular Architecture and Code Organization

**User Story:** As a developer, I want a clean modular codebase, so that I can maintain and extend the application efficiently.

#### Acceptance Criteria

1. THE Spreadsheet_App SHALL organize code into core, data, domain, presentation, and services layers
2. THE core layer SHALL contain constants, error definitions, utility functions, and network helpers
3. THE data layer SHALL contain models, repositories, data sources for local and remote data, and data mappers
4. THE domain layer SHALL contain business entities, repository interfaces, and use cases
5. THE domain use_cases folder SHALL include separate modules for sheet_management, cell_operations, formula_engine, import_export, api_integration, and ai_agent
6. THE presentation layer SHALL contain screen-specific folders including home, editor, import, and shared widgets
7. THE home folder SHALL contain widgets, home_screen.dart, and home_controller.dart files
8. THE editor folder SHALL contain subfolders for grid, toolbar, formula_bar, and cell_editor widgets
9. THE import folder SHALL contain subfolders for excel_import, csv_import, api_import, and google_forms_import
10. THE services layer SHALL contain service classes including storage_service, formula_service, rendering_service, api_service, and ai_agent_service
11. THE data repositories SHALL implement interfaces defined in the domain layer
12. THE presentation controllers SHALL depend only on domain use cases and not directly on data sources
13. THE Spreadsheet_App SHALL follow dependency injection patterns for service instantiation
14. THE Spreadsheet_App SHALL separate business logic from UI code with clear boundaries
15. THE Spreadsheet_App SHALL use data transfer objects (DTOs) for communication between layers

### Requirement 33: Column and Row Properties Bottom Sheet

**User Story:** As a user, I want to configure column and row properties, so that I can customize the appearance and behavior of my spreadsheet grid.

#### Acceptance Criteria

1. WHEN a user taps a Column_Header, THE Spreadsheet_App SHALL display a Column_Properties_Sheet sliding up from the bottom
2. THE Column_Properties_Sheet SHALL include a title bar displaying "Edit Column Properties" or "Column [Name]"
3. THE Column_Properties_Sheet SHALL include a Save button in the top-right corner
4. THE Column_Properties_Sheet SHALL include a back button in the top-left corner to dismiss the sheet
5. THE Column_Properties_Sheet SHALL display a text input field for Column Name with the current column letter as default
6. WHEN a user edits the Column Name field, THE Spreadsheet_App SHALL allow alphanumeric characters and spaces
7. THE Column_Properties_Sheet SHALL display a Column Type selector with options for Text, Number, Amount, Date, Time, Duration, Checkbox, and Image
8. THE Column Type selector SHALL display icons for each type including text icon, dollar sign, calendar, clock, checkbox, and image icon
9. WHEN a user selects a Column Type, THE Spreadsheet_App SHALL highlight the selected type with a distinct background color
10. THE Column_Properties_Sheet SHALL display a Column Width slider with minus and plus buttons
11. THE Column Width slider SHALL display the current width value as a numeric indicator
12. WHEN a user adjusts the Column Width slider, THE Grid_Renderer SHALL update the column width in real-time
13. THE Column_Properties_Sheet SHALL display a Styles section with formatting options
14. THE Styles section SHALL include buttons for Bold, Italic, Alignment (Left, Center, Right), Fill Color, Text Color, and Rotation
15. THE Column_Properties_Sheet SHALL display a preview text field showing how the column style will appear
16. WHEN a user applies a style, THE preview text SHALL update to reflect the formatting changes
17. THE Column_Properties_Sheet SHALL include a "Summary on Graph" option with an icon
18. WHEN a user taps "Summary on Graph", THE Spreadsheet_App SHALL enable chart generation for the column data
19. THE Column_Properties_Sheet SHALL include an "Insert Column on left" option with an icon
20. WHEN a user taps "Insert Column on left", THE Spreadsheet_App SHALL insert a new column to the left of the current column
21. THE Column_Properties_Sheet SHALL include a "Visible in table" toggle switch
22. WHEN a user disables "Visible in table", THE Grid_Renderer SHALL hide the column from view
23. WHEN a user taps Save, THE Spreadsheet_App SHALL apply all changes and close the Column_Properties_Sheet
24. WHEN a user taps the back button or taps outside the sheet, THE Spreadsheet_App SHALL dismiss the Column_Properties_Sheet without saving
25. WHEN a user taps a Row_Header, THE Spreadsheet_App SHALL display a Row_Properties_Sheet with similar configuration options
26. THE Row_Properties_Sheet SHALL include options for Row Height, Row Number, Hide Row, Insert Row Above, Insert Row Below, and Delete Row
27. THE Row_Properties_Sheet SHALL use the same Material Design 3 styling as the Column_Properties_Sheet
28. WHEN the Column_Properties_Sheet or Row_Properties_Sheet is displayed, THE Spreadsheet_App SHALL dim the background grid
29. THE Column_Properties_Sheet and Row_Properties_Sheet SHALL support drag-down gesture to dismiss
30. WHEN column properties are modified, THE Storage_Manager SHALL update the columns table with new values
