class Calculator:
    def add(self, x: float, y: float) -> float:
        """Add two numbers"""
        return x + y

    def subtract(self, x: float, y: float) -> float:
        """Subtract y from x"""
        return x - y

    def multiply(self, x: float, y: float) -> float:
        """Multiply two numbers"""
        return x * y

    def divide(self, x: float, y: float) -> float:
        """Divide x by y"""
        if y == 0:
            raise ValueError("Cannot divide by zero")
        return x / y

    def power(self, x: float, y: float) -> float:
        """Calculate x raised to the power of y"""
        return x ** y
