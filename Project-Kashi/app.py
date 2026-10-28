from flask import Flask, render_template, request, flash
from decimal import Decimal, InvalidOperation
import mysql.connector
import random

app = Flask(__name__)
app.secret_key = "kashi-secret-key"


def get_db():
    return mysql.connector.connect(
        host="localhost",
        port=3307,
        user="kashi",
        password="kashi123",
        database="kashi_bank"
    )


def run_proc(name, args):
    db = get_db()
    cur = db.cursor()
    try:
        cur.callproc(name, args)
        db.commit()
        return True, "Success"
    except mysql.connector.Error as e:
        return False, "Error: " + e.msg
    finally:
        cur.close()
        db.close()


def to_decimal(text):
    try:
        return Decimal(text)
    except InvalidOperation:
        return Decimal(0)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/register", methods=["GET", "POST"])
def register():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT BranchID, BranchName FROM Branch")
    branches = cur.fetchall()

    if request.method == "POST":
        f = request.form
        accno = str(random.randint(10**11, 10**12 - 1))
        try:
            cur.execute(
                """INSERT INTO Customer
                   (FirstName, LastName, DateOfBirth, Gender, Mobile, Email, Address, City)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
                (f["first"], f["last"], f["dob"], f["gender"], f["mobile"],
                 f["email"] or None, f["address"], f["city"]))
            cust_id = cur.lastrowid

            cur.execute(
                """INSERT INTO Account (AccountNumber, AccountType, OpeningDate, Balance, BranchID)
                   VALUES (%s,%s,CURDATE(),0,%s)""",
                (accno, f["acctype"], f["branch"]))
            acc_id = cur.lastrowid

            cur.execute(
                """INSERT INTO Account_Holder (CustomerID, AccountID, HolderSince, HolderType)
                   VALUES (%s,%s,CURDATE(),'Primary')""",
                (cust_id, acc_id))
            db.commit()

            amt = to_decimal(f.get("deposit", "0"))
            if amt > 0:
                cur.callproc("sp_deposit", (accno, amt))
                db.commit()
            flash("Account opened. Account number: " + accno)
        except mysql.connector.Error as e:
            db.rollback()
            flash("Error: " + e.msg)

    cur.close()
    db.close()
    return render_template("register.html", branches=branches)


@app.route("/deposit", methods=["GET", "POST"])
def deposit():
    if request.method == "POST":
        ok, msg = run_proc("sp_deposit",
                           (request.form["accno"], to_decimal(request.form["amount"])))
        flash(msg)
    return render_template("amount_form.html", title="Deposit")


@app.route("/withdraw", methods=["GET", "POST"])
def withdraw():
    if request.method == "POST":
        ok, msg = run_proc("sp_withdraw",
                           (request.form["accno"], to_decimal(request.form["amount"])))
        flash(msg)
    return render_template("amount_form.html", title="Withdraw")


@app.route("/transfer", methods=["GET", "POST"])
def transfer():
    if request.method == "POST":
        ok, msg = run_proc("sp_transfer",
                           (request.form["from_acc"], request.form["to_acc"],
                            to_decimal(request.form["amount"])))
        flash(msg)
    return render_template("transfer.html")


@app.route("/history")
def history():
    accno = request.args.get("accno")
    rows = []
    if accno:
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute(
            """SELECT t.TransactionDate, t.TransactionType, t.Amount,
                      t.ReferenceNumber, t.TransactionStatus, t.Description
               FROM `Transaction` t
               JOIN Account a ON t.AccountID = a.AccountID
               WHERE a.AccountNumber = %s
               ORDER BY t.TransactionDate DESC""", (accno,))
        rows = cur.fetchall()
        cur.close()
        db.close()
    return render_template("history.html", rows=rows, accno=accno)


@app.route("/accounts")
def accounts():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM vw_account_summary")
    rows = cur.fetchall()
    cur.close()
    db.close()
    return render_template("accounts.html", rows=rows)


if __name__ == "__main__":
    app.run(debug=True, port=5001)