#!/usr/bin/env python3
# Script Name: algerbra.py
# ID: SCR-ID-20260317130749-SNFNMT8GAN
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: algerbra

import sympy as sp
import os
import datetime

# Default log folder
LOG_DIR = "/mnt/c/Users/tyler/Documents/math/logs/"
os.makedirs(LOG_DIR, exist_ok=True)

def log_result(equation, solutions, formula_type):
    """Save the equation and solution to a timestamped log file."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    logfile = os.path.join(LOG_DIR, f"algebra_log_{timestamp}.txt")

    with open(logfile, "w") as f:
        f.write("=== Algebra Equation Solver Log ===\n")
        f.write(f"Time: {timestamp}\n")
        f.write(f"Equation Type: {formula_type}\n")
        f.write(f"Equation: {equation}\n")
        f.write(f"Solution(s): {solutions}\n")
    print(f"✅ Logged to {logfile}")

def main():
    print("Algebra Solver (SymPy)")
    print("You can enter equations like:")
    print(" - Linear: 2*x + 5 = 15")
    print(" - Quadratic: x**2 + 5*x + 6 = 0")
    print(" - Polynomial: x**3 - 4*x**2 + x - 6 = 0")
    print(" - Systems: x + y - 2, x - y - 4 (comma separated)")
    print("Press Ctrl+C to exit.\n")

    x, y, z = sp.symbols('x y z')  # default variables

    while True:
        try:
            user_input = input("Enter equation(s): ").strip()
            if not user_input:
                continue

            # Detect multiple equations (system of equations)
            if "," in user_input:
                eqs = [sp.Eq(sp.sympify(expr.split("=")[0]),
                             sp.sympify(expr.split("=")[1]))
                       if "=" in expr else sp.sympify(expr)
                       for expr in user_input.split(",")]
                vars = list({s for e in eqs for s in e.free_symbols})
                solutions = sp.solve(eqs, vars, dict=True)
                formula_type = "System of Equations"
            else:
                if "=" in user_input:
                    left, right = user_input.split("=")
                    eq = sp.Eq(sp.sympify(left), sp.sympify(right))
                else:
                    eq = sp.sympify(user_input)

                solutions = sp.solve(eq)
                # Guess type of equation
                degree = sp.Poly(eq.lhs - eq.rhs if isinstance(eq, sp.Equality) else eq).degree()
                formula_type = f"Polynomial (degree {degree})" if degree > 1 else "Linear"

            print(f"Solutions: {solutions}")
            log_result(user_input, solutions, formula_type)

        except Exception as e:
            print(f"⚠️ Error: {e}")

if __name__ == "__main__":
    main()
