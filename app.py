from flask import Flask, render_template, request, redirect, url_for, session
import mysql.connector

app = Flask(__name__)
app.secret_key = "supersecretkey"  # for session handling

# MySQL connection
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="root",
    database="gamestore_db"
)
cursor = db.cursor(dictionary=True)

# ---------------------- LOGIN ----------------------
@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        role = request.form['role']
        username = request.form['username']
        password = request.form['password']

        if role == 'user':
            cursor.execute("SELECT * FROM users WHERE username=%s AND password=%s", (username, password))
            user = cursor.fetchone()
            if user:
                session['role'] = 'user'
                session['user_id'] = user['user_id']
                return redirect(url_for('user_dashboard'))
            else:
                return render_template('login.html', error="Invalid user credentials")

        elif role == 'publisher':
            cursor.execute("SELECT * FROM publishers WHERE name=%s AND password=%s", (username, password))
            pub = cursor.fetchone()
            if pub:
                session['role'] = 'publisher'
                session['publisher_id'] = pub['publisher_id']
                return redirect(url_for('publisher_dashboard'))
            else:
                return render_template('login.html', error="Invalid publisher credentials")

    return render_template('login.html')


# ---------------------- PUBLISHER VIEW ----------------------
@app.route('/publisher')
def publisher_dashboard():
    if 'publisher_id' not in session:
        return redirect('/')
    pid = session['publisher_id']
    cursor.execute("SELECT * FROM games WHERE publisher_id = %s", (pid,))
    games = cursor.fetchall()
    return render_template('publisher_dashboard.html', games=games)

@app.route('/add_game', methods=['POST'])
def add_game():
    if 'publisher_id' not in session:
        return redirect('/')
    pid = session['publisher_id']
    title = request.form['title']
    genre = request.form['genre']
    price = request.form['price']
    cursor.execute("INSERT INTO games (title, genre, price, publisher_id) VALUES (%s, %s, %s, %s)", (title, genre, price, pid))
    db.commit()
    return redirect('/publisher')


# ---------------------- USER VIEW ----------------------
@app.route('/user')
def user_dashboard():
    if 'user_id' not in session:
        return redirect('/')
    cursor.execute("SELECT * FROM games")
    games = cursor.fetchall()
    return render_template('user_dashboard.html', games=games)

@app.route('/add_to_cart/<int:game_id>')
def add_to_cart(game_id):
    if 'user_id' not in session:
        return redirect('/')
    uid = session['user_id']
    cursor.execute("INSERT INTO cart (user_id, game_id) VALUES (%s, %s)", (uid, game_id))
    db.commit()
    return redirect('/user')

@app.route('/cart')
def cart():
    if 'user_id' not in session:
        return redirect('/')
    uid = session['user_id']
    cursor.execute("""
        SELECT c.cart_id, g.title, g.genre, g.price
        FROM cart c
        JOIN games g ON c.game_id = g.game_id
        WHERE c.user_id = %s
    """, (uid,))
    items = cursor.fetchall()
    return render_template('cart.html', items=items)

@app.route('/checkout')
def checkout():
    if 'user_id' not in session:
        return redirect('/')
    uid = session['user_id']
    cursor.execute("SELECT game_id FROM cart WHERE user_id = %s", (uid,))
    cart_items = cursor.fetchall()
    for item in cart_items:
        cursor.execute("INSERT INTO purchases (user_id, game_id) VALUES (%s, %s)", (uid, item['game_id']))
    cursor.execute("DELETE FROM cart WHERE user_id = %s", (uid,))
    db.commit()
    return redirect('/purchases')

@app.route('/purchases')
def purchases():
    if 'user_id' not in session:
        return redirect('/')
    uid = session['user_id']
    cursor.execute("""
        SELECT p.purchase_id, g.title, g.genre, g.price, p.purchase_date
        FROM purchases p
        JOIN games g ON p.game_id = g.game_id
        WHERE p.user_id = %s
        ORDER BY p.purchase_date DESC
    """, (uid,))
    purchases = cursor.fetchall()
    return render_template('purchases.html', purchases=purchases)


# ---------------------- LOGOUT ----------------------
@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')


if __name__ == '__main__':
    app.run(debug=True)
