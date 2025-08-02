# Calculator Project

A simple calculator implementation in Python with comprehensive unit tests.

## Features

- Basic arithmetic operations (add, subtract, multiply, divide)
- Power operation
- Input validation
- Comprehensive test suite

## Setup

1. Clone the repository
2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running Tests

To run tests with coverage:

```bash
pytest tests/ --cov=src/ --cov-report=html
```

## Project Structure

```
calculator-project/
├── src/
│   └── calculator.py
├── tests/
│   └── test_calculator.py
├── .github/
│   └── workflows/
│       └── python-unit-tests.yml
└── requirements.txt
```
