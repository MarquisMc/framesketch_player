# 🧠 Flutter Architecture Refactor Agent Skill

## Goal
Improve the architecture of a Flutter codebase using scalable, maintainable Flutter practices **without breaking existing behavior**.

---

## 🧩 Core Principles

### 1. Keep Widgets Dumb
- Widgets should primarily render UI
- Move business logic, API calls, validation, and state mutations out of widgets

---

### 2. Use Clear Layers

- **UI Layer**
  Screens
  Widgets
  ViewModels / Controllers

- **Data Layer**
  Repositories
  Services (API, DB)
  DTOs / Models

- **Optional Domain Layer**
  Use cases
  Business rules
  Entities
  👉 Only add when logic becomes complex

---

### 3. Prefer Feature-First Organization

```txt
lib/
  app/
    router/
    theme/
    di/
  core/
    errors/
    network/
    utils/
  features/
    auth/
      data/
        auth_repository.dart
        auth_api_service.dart
        models/
      presentation/
        login_screen.dart
        login_view_model.dart
        widgets/
    dashboard/
      data/
      presentation/
---

### 4. Repositories = Single Source of Truth

- UI should NEVER call APIs directly
- ViewModels depend on repositories
- Repositories coordinate:
  - API
  - cache
  - local storage

---  API
  cache
  local storage

### 5. Unidirectional Data Flow

```txt
### 6. Use Immutable State

- Prefer immutable models
- Use `copyWith`
- Use clear states:
  - `initial`
  - `loading`
  - `success`
  - `error`

---### 7. Dependency Injection

- Avoid hidden globals
- Inject dependencies via:
  - constructor
  - Provider / Riverpod
### 8. Make Code Testable

- Business logic should NOT depend on UI
- Repositories should be mockable
- ViewModels should be unit testable

---## 🔍 Agent Workflow

### Step 1: Inspect

Analyze:

### Step 2: Report Findings
- duplicated logic
- business logic inside UI
- direct API/database calls from widgets

---- Repositories should be mockable.
- ViewModels should be unit testable.
### Step 3: Refactor Safely

Follow this order:

1. Extract large widgets
2. Move logic → ViewModels
3. Introduce repositories
4. Normalize models & state
5. Improve folder structure
### Step 4: Avoid Over-Engineering

❌ **Don't:**

- Add Clean Architecture everywhere
- Create use cases for simple CRUD
- Add unnecessary abstractions
- Switch state management without reason
- Rewrite the entire app at once

---### Step 2: Report Findings

Architecture Review:
## 📱 Flutter Best Practices

### ❌ BAD (Logic in Widget)
1. Extract large widgets.
2. Move logic -> ViewModels.
3. Introduce repositories.
4. Normalize models and state.
### ViewModel Example
```

### ✅ GOOD (Delegated Logic)

```dart
onPressed: viewModel.loadUsers
```

### ViewModel Example

```dart
class UserViewModel extends ChangeNotifier {
  UserViewModel(this._repository);

  final UserRepository _repository;

  bool isLoading = false;
  List<User> users = [];
  String? error;

  Future<void> loadUsers() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      users = await _repository.getUsers();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
## 🚨 Architecture Smells

Watch for:

- `setState` doing too much
- API calls inside widgets
- validation logic in UI
- duplicated loading/error logic
- large files with mixed responsibilities
- deeply nested widgets
- direct service imports in UI
- global mutable state
- hardcoded routes everywhere
- untested business logic

---## � Output Format

When making changes:
- global mutable state
- hardcoded routes everywhere
- untested business logic

## 📤 Output Format

When making changes:

- Changes made:
  - ...
- Why this improves architecture:
  - ...
- Files changed:
  - ...
- Recommended next step:
  - ...

## ✅ Success Criteria

A refactor is successful when:
## 🧠 When to Add a Domain Layer

ONLY when:

- Logic is reused across features
- Rules become complex (multiple conditions)
- There are real-world constraints (economy, scoring, permissions)
- You need isolated testing of logic

## ⚡ Rule of Thumb

| App Type | Domain Layer |
|----------|--------------|
| Simple CRUD / tools | ❌ No |
| Medium app with some logic | ⚠️ Maybe |
| Simulation / game / learning system | ✅ Yes |

---- Rules become complex (multiple conditions).
- There are real-world constraints (economy, scoring, permissions).
- You need isolated testing of logic.
## 🎯 Final Note

Optimize for:

1. simplicity first
2. scalability second
3. perfection last

---

**Good architecture should make your app easier to change — not harder to understand.**## 🎯 Final Note

Optimize for:

- simplicity first
- scalability second
- perfection last

Good architecture should make your app easier to change, not harder to understand.