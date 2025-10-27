from flask import Flask, render_template, request, redirect, url_for, session
import mysql.connector

app = Flask(__name__)
app.secret_key = "supersecretkey"

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

# ---------------------- REGISTER ----------------------
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        role = request.form['role']
        username = request.form['username']
        password = request.form['password']
        
        if role == 'publisher':
            cursor.execute("SELECT * FROM publishers WHERE name = %s", (username,))
            if cursor.fetchone():
                return render_template('register.html', error="Publisher name already exists")
            cursor.execute("INSERT INTO publishers (name, password) VALUES (%s, %s)", (username, password))
            db.commit()
            return redirect('/')
        else:
            cursor.execute("SELECT * FROM users WHERE username=%s", (username,))
            if cursor.fetchone():
                return render_template('register.html', error="Username already exists")
            cursor.execute("INSERT INTO users (username, password) VALUES (%s, %s)", (username, password))
            db.commit()
            return redirect('/')
    return render_template('register.html')

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
    cursor.execute("INSERT INTO games (title, genre, price, publisher_id) VALUES (%s, %s, %s, %s)", 
                   (title, genre, price, pid))
    db.commit()
    return redirect('/publisher')

@app.route('/edit_game/<int:game_id>', methods=['GET', 'POST'])
def edit_game(game_id):
    if 'publisher_id' not in session:
        return redirect('/')
    
    if request.method == 'POST':
        title = request.form['title']
        genre = request.form['genre']
        price = request.form['price']
        
        cursor.execute("""
            UPDATE games 
            SET title = %s, genre = %s, price = %s 
            WHERE game_id = %s AND publisher_id = %s
        """, (title, genre, price, game_id, session['publisher_id']))
        db.commit()
        return redirect('/publisher')
    else:
        cursor.execute("SELECT * FROM games WHERE game_id = %s AND publisher_id = %s", 
                      (game_id, session['publisher_id']))
        game = cursor.fetchone()
        if not game:
            return redirect('/publisher')
        return render_template('edit_game.html', game=game)

@app.route('/delete_game/<int:game_id>')
def delete_game(game_id):
    if 'publisher_id' not in session:
        return redirect('/')
    
    cursor.execute("DELETE FROM games WHERE game_id = %s AND publisher_id = %s", 
                   (game_id, session['publisher_id']))
    db.commit()
    return redirect('/publisher')

# ---------------------- USER VIEW (WITH FILTERING) ----------------------
@app.route('/user')
def user_dashboard():
    if 'user_id' not in session:
        return redirect('/')
    
    # Get search parameter only
    search = request.args.get('search', '')
    
    # Build query with search
    if search:
        cursor.execute("SELECT * FROM games WHERE title LIKE %s", (f"%{search}%",))
    else:
        cursor.execute("SELECT * FROM games")
    
    games = cursor.fetchall()
    return render_template('user_dashboard.html', games=games, search=search)

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
        SELECT c.cart_id, g.title, g.genre, g.price, g.game_id
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

# ---------------------- PROFILE ----------------------
@app.route('/profile/<who>', methods=['GET', 'POST'])
def profile(who):
    logged_in_id = session.get('user_id') if who == 'user' else session.get('publisher_id')
    if not logged_in_id:
        return redirect('/')
    
    if request.method == 'POST':
        new_username = request.form['username']
        new_password = request.form['password']
        if who == 'user':
            cursor.execute("UPDATE users SET username=%s, password=%s WHERE user_id=%s", 
                         (new_username, new_password, logged_in_id))
        else:
            cursor.execute("UPDATE publishers SET name=%s, password=%s WHERE publisher_id=%s", 
                         (new_username, new_password, logged_in_id))
        db.commit()
        return redirect(url_for('profile', who=who))
    
    # Load profile
    if who == 'user':
        cursor.execute("SELECT * FROM users WHERE user_id=%s", (logged_in_id,))
        profile = cursor.fetchone()
    else:
        cursor.execute("SELECT * FROM publishers WHERE publisher_id=%s", (logged_in_id,))
        profile = cursor.fetchone()
    return render_template('profile.html', profile=profile, who=who)

@app.route('/delete_account/<who>', methods=['POST'])
def delete_account(who):
    logged_in_id = session.get('user_id') if who == 'user' else session.get('publisher_id')
    if not logged_in_id:
        return redirect('/')
    if who == 'user':
        cursor.execute("DELETE FROM users WHERE user_id=%s", (logged_in_id,))
    else:
        cursor.execute("DELETE FROM publishers WHERE publisher_id=%s", (logged_in_id,))
    db.commit()
    session.clear()
    return redirect('/')

# ---------------------- LOGOUT ----------------------
@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')

if __name__ == '__main__':
    app.run(debug=True)
