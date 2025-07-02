import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/bottom_navigation_bar.dart';
import 'task_input_fragment.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDayIndex = 1;
  late List<DateTime> _dates;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dates = [
      today.subtract(const Duration(days: 1)),
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
      today.add(const Duration(days: 3)),
    ];
    _loadTasksForSelectedDate();
  }

  void _selectDay(int index) {
    setState(() {
      _selectedDayIndex = index;
    });
    _loadTasksForSelectedDate();
  }

  Future<void> _loadTasksForSelectedDate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final selectedDate = _dates[_selectedDayIndex];
      final tasksData = await SupabaseService.getTasksForDate(selectedDate);
      
      for (final task in tasksData) {
        if (task['is_recurring'] == true) {
          final dateString = selectedDate.toIso8601String().split('T')[0];
          try {
            final completionRecord = await SupabaseService.client
                .from('task_completions')
                .select('completed')
                .eq('original_task_id', task['id'])
                .eq('completion_date', dateString)
                .maybeSingle();
            
            task['checked'] = completionRecord?['completed'] ?? false;
          } catch (e) {
            task['checked'] = false;
          }
        }
      }

      setState(() {
        _tasks = tasksData;
        _isLoading = false;
      });

      debugPrint('Loaded ${_tasks.length} tasks for date: ${selectedDate.toIso8601String().split('T')[0]}');
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _tasks = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(int taskId, bool isChecked) async {
    try {
      final selectedDate = _dates[_selectedDayIndex];
      final taskIndex = _tasks.indexWhere((task) => task['id'] == taskId);
      
      if (taskIndex != -1) {
        final task = _tasks[taskIndex];
        final isRecurring = task['is_recurring'] == true;
        final dateString = selectedDate.toIso8601String().split('T')[0];
        
        // Update the UI immediately for better user experience
        setState(() {
          _tasks[taskIndex]['checked'] = isChecked;
        });
        
        // Then update the database
        await SupabaseService.updateTaskStatus(
          taskId, 
          isChecked, 
          isRecurring: isRecurring,
          taskDate: isRecurring ? dateString : null,
        );

        debugPrint('Task status updated: $taskId -> $isChecked (recurring: $isRecurring)');
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
      // Revert the UI change if database update failed
      final taskIndex = _tasks.indexWhere((task) => task['id'] == taskId);
      if (taskIndex != -1) {
        setState(() {
          _tasks[taskIndex]['checked'] = !isChecked;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return date.day.toString();
  }

  String _formatWeekday(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(180),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: AssetImage('lib/assets/watch.jpg'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Disconnected',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 5; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDay(i),
                            child: Container(
                              height: 90,
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: i == _selectedDayIndex ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: i == _selectedDayIndex
                                    ? [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                          offset: Offset(0, 3),
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (i == 1)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == _selectedDayIndex 
                                            ? Colors.black 
                                            : Colors.white,
                                      ),
                                    ),
                                  Text(
                                    _formatDate(_dates[i]),
                                    style: TextStyle(
                                      color: i == _selectedDayIndex
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatWeekday(_dates[i]),
                                    style: TextStyle(
                                      color: i == _selectedDayIndex
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : _tasks.isEmpty
              ? Center(
                  child: Text(
                    'No task list',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final isChecked = task['checked'] ?? false;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Container(
                        width: double.infinity,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
                              children: [
                                Container(
                                  width: constraints.maxWidth * 0.15,
                                  height: constraints.maxHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      try {
                                        await SupabaseService.deleteTask(task['id']);
                                        _loadTasksForSelectedDate();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error deleting task: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        debugPrint('Error deleting task: $e');
                                      }
                                    },
                                    child: Center(
                                      child: Icon(
                                        Icons.delete_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                task['task_description'] ?? 'No description',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                task['repeat_option'] ?? 'None',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (task['image_url'] != null) ...[
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                barrierColor: Colors.transparent,
                                                builder: (BuildContext context) {
                                                  return BackdropFilter(
                                                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                                    child: Dialog(
                                                      backgroundColor: Colors.transparent,
                                                      child: Stack(
                                                        children: [
                                                          Center(
                                                            child: Container(
                                                              width: MediaQuery.of(context).size.width * 0.9,
                                                              height: MediaQuery.of(context).size.height * 0.7,
                                                              decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: ClipRRect(
                                                                borderRadius: BorderRadius.circular(12),
                                                                child: Image.network(
                                                                  task['image_url'],
                                                                  fit: BoxFit.contain,
                                                                  errorBuilder: (context, error, stackTrace) {
                                                                    return Container(
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.grey[300],
                                                                        borderRadius: BorderRadius.circular(12),
                                                                      ),
                                                                      child: Center(
                                                                        child: Icon(
                                                                          Icons.image_not_supported,
                                                                          color: Colors.grey,
                                                                          size: 48,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Positioned(
                                                            bottom: 40,
                                                            left: 0,
                                                            right: 0,
                                                            child: Center(
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  Navigator.of(context).pop();
                                                                },
                                                                child: Container(
                                                                  padding: EdgeInsets.all(12),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.black54,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: Icon(
                                                                    Icons.close,
                                                                    color: Colors.white,
                                                                    size: 24,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  task['image_url'],
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.image_not_supported,
                                                        color: Colors.grey,
                                                        size: 24,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Transform.scale(
                                    scale: 1.5,
                                    child: Checkbox(
                                      value: isChecked,
                                      onChanged: (bool? value) {
                                        _updateTaskStatus(task['id'], value ?? false);
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                      checkColor: Colors.white,
                                      fillColor: MaterialStateProperty.resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                          if (states.contains(MaterialState.selected)) {
                                            return Colors.black;
                                          }
                                          return Colors.transparent;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 1),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaskInputFragment(
                title: 'Add Task',
              ),
            ),
          );
          if (result != null) {
            debugPrint('Task added: $result');
            _loadTasksForSelectedDate();
          }
        },
        backgroundColor: Colors.black,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}