import pytest
from src.calculator import Calculator

@pytest.fixture
def calculator():
    return Calculator()

def test_addition(calculator):
    assert calculator.add(2, 3) == 5
    assert calculator.add(-1, 1) == 0
    assert calculator.add(0, 0) == 0
    assert calculator.add(0.1, 0.2) == pytest.approx(0.3)

def test_subtraction(calculator):
    assert calculator.subtract(5, 3) == 2
    assert calculator.subtract(1, 1) == 0
    assert calculator.subtract(0, 5) == -5
    assert calculator.subtract(10.5, 0.5) == 10.0

def test_multiplication(calculator):
    assert calculator.multiply(2, 3) == 6
    assert calculator.multiply(-2, 3) == -6
    assert calculator.multiply(0, 5) == 0
    assert calculator.multiply(0.5, 2) == 1.0

def test_division(calculator):
    assert calculator.divide(6, 2) == 3
    assert calculator.divide(5, 2) == 2.5
    assert calculator.divide(0, 5) == 0
    assert calculator.divide(10, 0.5) == 20

def test_division_by_zero(calculator):
    with pytest.raises(ValueError, match="Cannot divide by zero"):
        calculator.divide(5, 0)

def test_power(calculator):
    assert calculator.power(2, 3) == 8
    assert calculator.power(5, 0) == 1
    assert calculator.power(0, 5) == 0
    assert calculator.power(2, -1) == 0.5
