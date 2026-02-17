import math
import sys

def listify(x:int, N:int):
    """
    Take in a positive integer and return a zero padded list of length N
    """
    if x == 0:
        return [0]
    return_list = [0 for i in range(N)]
    assert 10**N > x, "Insufficiently large N to accomodate the provided x"
    i = 0
    while x > 0:
        return_list[i] = x % 10
        x = x // 10
        i += 1
    return return_list

x = listify(1, 1)
assert x[0] == 1

x = listify(15, 2)
assert x[0] == 5
assert x[1] == 1

x = listify(15, 4)
assert x[0] == 5
assert x[1] == 1
assert x[2] == 0
assert x[3] == 0

x = listify(15, 10)
assert x[0] == 5
assert x[1] == 1
assert x[2] == 0
assert x[3] == 0
assert x[4] == 0
assert x[5] == 0
assert x[6] == 0
assert x[7] == 0
assert x[8] == 0
assert x[9] == 0

x = listify(1565, 6)
assert x[0] == 5
assert x[1] == 6
assert x[2] == 5
assert x[3] == 1
assert x[4] == 0
assert x[5] == 0

def rgstring(a:int, b:int, N:int=0) -> list[str]:
    """
    Given two zero padded numbers with digits a and b, return the regex
    that matches all numbers between a and b
    """
    assert a >= 0, "Integer a must be greater than or equal to 0"
    assert b >= 0, "Integer b must be greater than or equal to 0"
    assert a <= b, "Integer a must be less than or equal to integer b"

    if b == 0:
        return "0"

    def prepend_digit(digit:int, string_list:list[str]) -> list[str]:
        """
        Prepend the digit before each instance 
        """
        return [str(digit) + s for s in string_list]

    def rgstring_helper(a:list[int], b:list[int]) -> list[str]:
        assert len(a) == len(b), "Arrays must be the same length"
        if len(a) == 1:
            return [f"[{a[0]}-{b[0]}]"]
        if b[-1] - a[-1] == 0:
            return prepend_digit(a[-1], rgstring_helper(a[0:-1], b[0:-1]))
        
        front = prepend_digit(a[-1], rgstring_helper(a[0:-1], [9 for i in range(len(a) - 1)]))
        middle = []
        if b[-1] - a[-1] == 2:
             middle = [str(a[-1] + 1)+ "[0-9]"*(len(a)-1)] 
        elif b[-1] - a[-1] > 2:
             middle = [f"[{a[-1]+1}-{b[-1]-1}]" + "[0-9]"*(len(a)-1)] 
        back = prepend_digit(b[-1], rgstring_helper([0 for i in range(len(b) - 1)], b[0:-1]))
        return front + middle + back

    if N == 0:
        padding = max(1, math.ceil(math.log(b, 10)))
    else:
        padding = N
    match_list = rgstring_helper(listify(a, padding), listify(b, padding))
    return match_list

result = rgstring(0, 0)
assert result == "0"

result = rgstring(0, 1)
assert result == ["[0-1]"]

result = rgstring(1, 1)
assert result == ["[1-1]"]

result = rgstring(1, 5)
assert result == ["[1-5]"]

result = rgstring(41, 45)
assert result == ["4[1-5]"]

result = rgstring(41, 55)
assert result == ["4[1-9]","5[0-5]"]

result = rgstring(41, 65)
assert result == ["4[1-9]","5[0-9]","6[0-5]"]

result = rgstring(21, 656)
result = rgstring(21, 6556)

result = rgstring(2024, 2045)

def date_utility(date1:str, date2:str) -> list[str]:
    """
    Dates must be given in YYYY-MM-DD format. Return the regular expression
    matching all days in between date1 and date2, inclusive.
    """
    d1 = dict(zip(["Year", "Month", "Day"], date1.split("-")))
    d2 = dict(zip(["Year", "Month", "Day"], date2.split("-")))
    
    if d1["Year"] == d2["Year"] and d1["Month"] == d2["Month"] and d1["Day"] == d2["Day"]:
        return []

    if int(d2["Year"]) - int(d1["Year"]) > 1:
        year_diff = rgstring(int(d1["Year"])+1, int(d2["Year"])-1)
        year_diff = [ ymatch + "-[0-1][0-9]-[0-3][0-9]" for ymatch in year_diff]
        return date_utility(f"{d1["Year"]}-{d1["Month"]}-{d1["Day"]}", f"{d1["Year"]}-12-31") + year_diff + date_utility(f"{d2["Year"]}-01-01", f"{d2["Year"]}-{d2["Month"]}-{d2["Day"]}")
    elif int(d2["Year"]) - int(d1["Year"]) == 1:
        return date_utility(f"{d1["Year"]}-{d1["Month"]}-{d1["Day"]}", f"{d1["Year"]}-12-31") + date_utility(f"{d2["Year"]}-01-01", f"{d2["Year"]}-{d2["Month"]}-{d2["Day"]}")
    elif int(d2["Month"]) - int(d1["Month"]) > 1:
        month_diff = rgstring(int(d1["Month"])+1, int(d2["Month"])-1, N=2)
        month_diff = [ d1["Year"] + "-" + mmatch + "-" + "[0-3][0-9]" for mmatch in month_diff ]
        return date_utility(f"{d1["Year"]}-{d1["Month"]}-{d1["Day"]}", f"{d1["Year"]}-{d1["Month"]}-31") + month_diff + date_utility(f"{d2["Year"]}-{d2["Month"]}-01", f"{d2["Year"]}-{d2["Month"]}-{d2["Day"]}")
    elif int(d2["Month"]) - int(d1["Month"]) == 1:
        return date_utility(f"{d1["Year"]}-{d1["Month"]}-{d1["Day"]}", f"{d1["Year"]}-{d1["Month"]}-31") + date_utility(f"{d2["Year"]}-{d2["Month"]}-01", f"{d2["Year"]}-{d2["Month"]}-{d2["Day"]}")
    else:
        return [f"{d1["Year"]}-{d1["Month"]}-" + dmatch for dmatch in rgstring(int(d1["Day"]), int(d2["Day"]), N=2)]

def get_date(date1:str, date2:str):
    regex_matchlist = date_utility(date1, date2)
    return (r"\|").join([r'\(\[\['+ r + r'\)' for r in regex_matchlist])

if __name__ == '__main__':
    print(get_date(*sys.argv[1:3]))
