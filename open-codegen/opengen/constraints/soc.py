import casadi.casadi as cs
import numpy as np
from .constraint import Constraint
import opengen.functions as fn


class SecondOrderCone(Constraint):
    """A Second-Order Cone given by C = {u = (x, r): a||x|| <= r}

    Second-order cones are used in conic optimisation to describe
    inequalities that involve quadratic terms

    """

    def __init__(self, a: float = 1.0):
        """Constructor for a Second-Order Cone set

        Args:
            :param a: parameter a

        Returns:
            New instance of a SOC with given parameter `a`
        """
        if a <= 0:
            raise Exception("Parameter `a` must be a positive number")

        self.__a = a

    @property
    def a(self):
        """Returns the value of parameter `a`"""
        return self.__a

    def distance_squared(self, u):
        """Computes the squared distance between a given point `u` and this
           second-order cone

            :param u: given point; can be a list of float, a numpy
                n-dim array (`ndarray`) or a CasADi SX/MX symbol

            :return: distance from set as a float or a CasADi symbol
        """

        if isinstance(u, cs.SX):
            raise Exception("This function does not accept casadi.SX; use casadi.MX instead")

        if fn.is_symbolic(u):
            # Case I: `u` is a CasADi SX symbol
            nu = u.size(1)
        elif (isinstance(u, list) and all(isinstance(x, (int, float)) for x in u)) \
                or isinstance(u, np.ndarray):
            nu = len(u)
        else:
            raise Exception("Illegal Argument, `u`")

        # Partition `u = (x, r)`, where `r` is the last element of `u`
        a = self.__a
        x = u[0:nu-1]
        r = u[nu-1]

        eps = 1e-16

        norm_x = fn.norm2(cs.fabs(x))  # norm of x
        sq_norm_x = cs.dot(x, x)  # squared norm of x
        beta = a ** 2 / (a ** 2 + 1.0)

        fun1 = 0
        fun2 = sq_norm_x + r ** 2
        fun3 = norm_x ** 2 \
               + beta * (a * norm_x + r) ** 2 \
               - 2.0 * a * norm_x * (a * norm_x + r) \
               + (r - (a * norm_x + r)/(a ** 2 + 1.0)) ** 2

        condition0 = norm_x + cs.fabs(r) < eps
        condition1 = r >= norm_x/a
        condition2 = r <= -a*norm_x

        f = cs.if_else(condition0, 0, cs.if_else(condition1, fun1,
                       cs.if_else(condition2, fun2, fun3, True), True), True)

        cs.Function

        return f

    def project(self, u):
        # Idea: Computes projection on Ball as follows
        #   Proj_B(u) = u / max{1, ||u||},
        # which avoids dividing by zero or defining the projections
        raise NotImplementedError()

