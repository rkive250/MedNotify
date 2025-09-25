from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, messaging
import os
import uuid

app = Flask(__name__)
CORS(app)

# Configuración base de datos y JWT
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://root:@localhost/sistema_usuarios'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'd917007c5d609be36618dd76993244efa4d0bb644f4dc6b62de13d49441d462a'

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)

# Inicializar Firebase Admin con la clave de cuenta de servicio
cred = credentials.Certificate('serviceAccountKey.json')  # Ajusta la ruta si es diferente
firebase_admin.initialize_app(cred)

# MODELOS
class Usuario(db.Model):
    __tablename__ = 'usuarios'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(100), nullable=False)
    correo = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

    glucosas = db.relationship('Glucosa', backref='usuario', lazy=True)
    presiones_arteriales = db.relationship('PresionArterial', backref='usuario', lazy=True)
    oxigenaciones = db.relationship('Oxigenacion', backref='usuario', lazy=True)
    frecuencias_cardiacas = db.relationship('FrecuenciaCardiaca', backref='usuario', lazy=True)
    medicamentos = db.relationship('Medicamento', backref='usuario', lazy=True)
    notificaciones = db.relationship('Notificacion', backref='usuario', lazy=True)
    fcm_tokens = db.relationship('FcmToken', backref='usuario', lazy=True, cascade='all, delete-orphan')

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)

class FcmToken(db.Model):
    __tablename__ = 'fcm_tokens'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    token = db.Column(db.String(255), nullable=False, unique=True)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class Glucosa(db.Model):
    __tablename__ = 'glucosas'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    hora = db.Column(db.Time, nullable=False)
    valor = db.Column(db.Numeric(5, 2), nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class PresionArterial(db.Model):
    __tablename__ = 'presiones_arteriales'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    hora = db.Column(db.Time, nullable=False)
    sistolica = db.Column(db.Integer, nullable=False)
    diastolica = db.Column(db.Integer, nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class Oxigenacion(db.Model):
    __tablename__ = 'oxigenaciones'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    hora = db.Column(db.Time, nullable=False)
    valor = db.Column(db.Integer, nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class FrecuenciaCardiaca(db.Model):
    __tablename__ = 'frecuencias_cardiacas'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    hora = db.Column(db.Time, nullable=False)
    valor = db.Column(db.Integer, nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class Medicamento(db.Model):
    __tablename__ = 'medicamentos'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    nombre = db.Column(db.String(100), nullable=False)
    dosis = db.Column(db.String(50), nullable=False)
    hora_toma = db.Column(db.Time, nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    sintomas = db.Column(db.Text)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

class Notificacion(db.Model):
    __tablename__ = 'notificaciones'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=False)
    mensaje = db.Column(db.String(255), nullable=False)
    fecha = db.Column(db.Date, nullable=False)
    hora = db.Column(db.Time, nullable=False)
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)
    delete_request_id = db.Column(db.String(36))  # Nuevo campo para rastrear solicitudes de eliminación

def enviar_notificacion_fcm(usuario_id, titulo, mensaje, delete_request_id=None):
    try:
        usuario = db.session.get(Usuario, usuario_id)
        if not usuario or not usuario.fcm_tokens:
            print(f"No hay tokens FCM para usuario_id: {usuario_id}")
            return False

        success = False
        for fcm_token in usuario.fcm_tokens:
            message = messaging.Message(
                notification=messaging.Notification(title=titulo, body=mensaje),
                token=fcm_token.token,
                android=messaging.AndroidConfig(priority='high'),
                data={'delete_request_id': delete_request_id} if delete_request_id else None
            )
            try:
                response = messaging.send(message)
                print(f'Notificación enviada con éxito al token {fcm_token.token}: {response}')
                success = True
            except Exception as e:
                print(f'Error al enviar notificación al token {fcm_token.token}: {str(e)}')
                if 'InvalidRegistration' in str(e) or 'NotRegistered' in str(e):
                    db.session.delete(fcm_token)
                    db.session.commit()
                    print(f'Token FCM eliminado: {fcm_token.token}')

        return success
    except Exception as e:
        print(f'Error general al enviar notificación FCM: {str(e)}')
        return False

# RUTAS
@app.route('/api/registro', methods=['POST'])
def registro():
    print("Solicitud recibida en /api/registro:", request.json)
    data = request.get_json(force=True)
    nombre = data.get('nombre')
    correo = data.get('correo')
    password = data.get('password')
    fcm_token = data.get('fcm_token')

    if not nombre or not correo or not password:
        print("Error: Faltan datos obligatorios")
        return jsonify({"msg": "Nombre, correo y contraseña son obligatorios"}), 400

    if Usuario.query.filter_by(correo=correo).first():
        print("Error: Correo ya registrado")
        return jsonify({"msg": "Correo ya registrado"}), 409

    usuario = Usuario(nombre=nombre, correo=correo)
    usuario.set_password(password)

    try:
        db.session.add(usuario)
        db.session.flush()  
        if fcm_token:
            fcm_token_entry = FcmToken(usuario_id=usuario.id, token=fcm_token)
            db.session.add(fcm_token_entry)
        db.session.commit()
        print("Usuario creado:", correo, "fcm_token:", fcm_token)
        access_token = create_access_token(identity=str(usuario.id))
        print("JWT creado para:", correo)
        return jsonify({"msg": "Usuario creado", "access_token": access_token}), 201
    except Exception as e:
        print("Error al guardar usuario:", str(e))
        db.session.rollback()
        return jsonify({"msg": f"Error interno: {str(e)}"}), 500

@app.route('/api/login', methods=['POST'])
def login():
    print("Solicitud recibida en /api/login:", request.json)
    data = request.get_json(force=True)
    correo = data.get('correo')
    password = data.get('password')
    fcm_token = data.get('fcm_token')

    usuario = Usuario.query.filter_by(correo=correo).first()
    if usuario and usuario.check_password(password):
        if fcm_token:
            existing_token = FcmToken.query.filter_by(token=fcm_token).first()
            if not existing_token:
                fcm_token_entry = FcmToken(usuario_id=usuario.id, token=fcm_token)
                db.session.add(fcm_token_entry)
                try:
                    db.session.commit()
                    print("FCM token añadido para:", correo, "fcm_token:", fcm_token)
                except Exception as e:
                    print("Error al añadir fcm_token:", str(e))
                    db.session.rollback()
                    return jsonify({"msg": f"Error interno al actualizar token: {str(e)}"}), 500
        access_token = create_access_token(identity=str(usuario.id))
        print("Login exitoso para:", correo)
        return jsonify({"access_token": access_token}), 200
    else:
        print("Error: Credenciales inválidas")
        return jsonify({"msg": "Credenciales inválidas"}), 401


@app.route('/api/save_fcm_token', methods=['POST'])
@jwt_required()
def save_fcm_token():
    usuario_id = get_jwt_identity()
    print(f"Usuario ID autenticado: {usuario_id}")
    try:
        data = request.get_json(force=True)
        print(f"Datos recibidos en save_fcm_token: {data}")
        fcm_token = data.get('fcm_token')
        if not fcm_token:
            print("Error: FCM token no proporcionado")
            return jsonify({"msg": "FCM token is required"}), 400
        usuario = db.session.get(Usuario, int(usuario_id))
        if not usuario:
            print(f"Error: Usuario no encontrado, ID: {usuario_id}")
            return jsonify({"msg": "User not found"}), 404
        existing_token = FcmToken.query.filter_by(token=fcm_token).first()
        if not existing_token:
            fcm_token_entry = FcmToken(usuario_id=usuario_id, token=fcm_token)
            db.session.add(fcm_token_entry)
            db.session.commit()
            print(f"FCM token guardado para usuario: {usuario_id}")
        return jsonify({"msg": "FCM token saved"}), 200
    except Exception as e:
        print(f"Error en save_fcm_token: {str(e)}")
        db.session.rollback()
        return jsonify({"msg": f"Error procesando la solicitud: {str(e)}"}), 422

# ... (importaciones y configuraciones previas se mantienen iguales)

@app.route('/api/registros_salud', methods=['POST'])
@jwt_required()
def crear_registro():
    usuario_id = get_jwt_identity()
    try:
        data = request.get_json(force=True)
        print(f"Datos recibidos en registros_salud: {data}")

        fecha_str = data.get('fecha')
        hora_str = data.get('hora')
        tipo = data.get('tipo')

        if not fecha_str or not hora_str or not tipo:
            print("Error: Faltan datos obligatorios")
            return jsonify({"msg": "Fecha, hora y tipo son requeridos"}), 400

        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
            hora = datetime.strptime(hora_str, '%H:%M:%S').time()
        except ValueError as e:
            print(f"Error de formato: {str(e)}")
            return jsonify({"msg": f"Formato de fecha o hora inválido: {str(e)}"}), 400

        if tipo == 'glucosa':
            try:
                valor = float(data.get('valor'))
                if valor < 0 or valor > 999.99:
                    print("Error: Valor de glucosa fuera de rango")
                    return jsonify({"msg": "El valor de glucosa debe estar entre 0 y 999.99"}), 400
                registro = Glucosa(usuario_id=usuario_id, fecha=fecha, hora=hora, valor=valor)

                nivel = 'Normal' if 70 <= valor <= 180 else 'Bajo' if valor < 70 else 'Alto'
                mensaje = f'Tu glucosa está en nivel {nivel.lower()} ({valor} mg/dL)'
                
                notificacion = Notificacion(
                    usuario_id=usuario_id,
                    mensaje=mensaje,
                    fecha=fecha,
                    hora=hora,
                )
                db.session.add(notificacion)

                enviar_notificacion_fcm(
                    usuario_id,
                    'WHS Medicine - Glucosa',
                    mensaje,
                    None
                )

            except (ValueError, TypeError):
                print("Error: Valor de glucosa inválido")
                return jsonify({"msg": "Valor de glucosa inválido"}), 400

        elif tipo == 'presion_arterial':
            try:
                sistolica = int(data.get('sistolica'))
                diastolica = int(data.get('diastolica'))
                if sistolica < 0 or diastolica < 0:
                    print("Error: Valores de presión arterial inválidos")
                    return jsonify({"msg": "Los valores de presión arterial deben ser positivos"}), 400
                registro = PresionArterial(
                    usuario_id=usuario_id,
                    fecha=fecha,
                    hora=hora,
                    sistolica=sistolica,
                    diastolica=diastolica
                )
            except (ValueError, TypeError):
                print("Error: Valores de presión arterial inválidos")
                return jsonify({"msg": "Valores de presión arterial inválidos"}), 400

        elif tipo == 'oxigenacion':
            try:
                valor = int(data.get('valor'))
                if valor < 0 or valor > 100:
                    print("Error: Valor de oxigenación fuera de rango")
                    return jsonify({"msg": "El valor de oxigenación debe estar entre 0 y 100"}), 400
                registro = Oxigenacion(usuario_id=usuario_id, fecha=fecha, hora=hora, valor=valor)
            except (ValueError, TypeError):
                print("Error: Valor de oxigenación inválido")
                return jsonify({"msg": "Valor de oxigenación inválido"}), 400

        elif tipo == 'frecuencia_cardiaca':
            try:
                valor = int(data.get('valor'))
                if valor < 0 or valor > 300:
                    print("Error: Valor de frecuencia cardíaca fuera de rango")
                    return jsonify({"msg": "El valor de frecuencia cardíaca debe estar entre 0 y 300"}), 400
                registro = FrecuenciaCardiaca(usuario_id=usuario_id, fecha=fecha, hora=hora, valor=valor)
            except (ValueError, TypeError):
                print("Error: Valor de frecuencia cardíaca inválido")
                return jsonify({"msg": "Valor de frecuencia cardíaca inválido"}), 400

        else:
            print("Error: Tipo de registro inválido")
            return jsonify({"msg": "Tipo de registro inválido"}), 400

        db.session.add(registro)
        db.session.commit()
        print(f"Registro creado para usuario: {usuario_id}, tipo: {tipo}")

        hoy = fecha
        total_registros = (
            db.session.query(Glucosa).filter_by(usuario_id=usuario_id, fecha=hoy).count() +
            db.session.query(PresionArterial).filter_by(usuario_id=usuario_id, fecha=hoy).count() +
            db.session.query(Oxigenacion).filter_by(usuario_id=usuario_id, fecha=hoy).count() +
            db.session.query(FrecuenciaCardiaca).filter_by(usuario_id=usuario_id, fecha=hoy).count()
        )

        if total_registros >= 2:
            glucosa = db.session.query(Glucosa).filter_by(usuario_id=usuario_id, fecha=hoy).order_by(Glucosa.fecha.desc(), Glucosa.hora.desc()).first()
            presion = db.session.query(PresionArterial).filter_by(usuario_id=usuario_id, fecha=hoy).order_by(PresionArterial.fecha.desc(), PresionArterial.hora.desc()).first()
            oxigenacion = db.session.query(Oxigenacion).filter_by(usuario_id=usuario_id, fecha=hoy).order_by(Oxigenacion.fecha.desc(), Oxigenacion.hora.desc()).first()
            frecuencia = db.session.query(FrecuenciaCardiaca).filter_by(usuario_id=usuario_id, fecha=hoy).order_by(FrecuenciaCardiaca.fecha.desc(), FrecuenciaCardiaca.hora.desc()).first()

            resumen = f"Resumen diario ({hoy}): "
            partes = []
            if glucosa:
                nivel = 'Normal' if 70 <= float(glucosa.valor) <= 180 else 'Bajo' if float(glucosa.valor) < 70 else 'Alto'
                partes.append(f"Glucosa: {glucosa.valor} mg/dL ({nivel})")
            if presion:
                partes.append(f"Presión: {presion.sistolica}/{presion.diastolica} mmHg")
            if oxigenacion:
                partes.append(f"Oxigenación: {oxigenacion.valor}%")
            if frecuencia:
                partes.append(f"Frecuencia cardíaca: {frecuencia.valor} bpm")
            
            resumen += "; ".join(partes)

            notificacion_resumen = Notificacion(
                usuario_id=usuario_id,
                mensaje=resumen,
                fecha=hoy,
                hora=datetime.utcnow().time(),
            )
            db.session.add(notificacion_resumen)
            db.session.commit()

            enviar_notificacion_fcm(
                usuario_id,
                'WHS Medicine - Resumen Diario',
                resumen,
                None
            )
            print(f"Notificación de resumen diario enviada para usuario_id: {usuario_id}")

        return jsonify({"msg": "Registro creado", "id": registro.id}), 201
    except Exception as e:
        print(f"Error al guardar registro: {str(e)}")
        db.session.rollback()
        return jsonify({"msg": f"Error procesando la solicitud: {str(e)}"}), 422


@app.route('/api/notificaciones', methods=['GET'])
@jwt_required()
def obtener_notificaciones():
    usuario_id = get_jwt_identity()
    notificaciones = Notificacion.query.filter_by(usuario_id=usuario_id).order_by(
        Notificacion.fecha.desc(), Notificacion.hora.desc()
    ).all()
    resultado = [{
        "id": n.id,
        "mensaje": n.mensaje,
        "fecha": n.fecha.isoformat(),
        "hora": n.hora.strftime('%H:%M:%S'),
        "fecha_creacion": n.fecha_creacion.isoformat(),
        "delete_request_id": n.delete_request_id if n.delete_request_id else None
    } for n in notificaciones]
    print(f"Notificaciones obtenidas para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200

@app.route('/api/glucosas/<int:id>', methods=['DELETE'])
@jwt_required()
def eliminar_glucosa(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Glucosa, id)
    if not registro:
        print(f"Registro de glucosa no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para glucosa id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    delete_request_id = str(uuid.uuid4())
    mensaje = f'Confirma la eliminación del registro de glucosa del {registro.fecha} a las {registro.hora.strftime("%H:%M")} (ID: {id})'
    
    notificacion = Notificacion(
        usuario_id=usuario_id,
        mensaje=mensaje,
        fecha=datetime.utcnow().date(),
        hora=datetime.utcnow().time(),
        delete_request_id=delete_request_id
    )
    db.session.add(notificacion)
    try:
        db.session.commit()
        print(f"Notificación creada con delete_request_id: {delete_request_id}, mensaje: {mensaje}")
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear notificación: {str(e)}")
        return jsonify({"msg": f"Error al crear notificación: {str(e)}"}), 500

    if enviar_notificacion_fcm(
        usuario_id,
        'WHS Medicine - Confirmar Eliminación',
        mensaje,
        delete_request_id
    ):
        return jsonify({"msg": "Solicitud de eliminación enviada. Confirma desde la notificación.", "delete_request_id": delete_request_id}), 200
    else:
        print(f"Error al enviar notificación FCM para usuario_id: {usuario_id}")
        return jsonify({"msg": "Error al enviar notificación"}), 500

@app.route('/api/confirm_delete', methods=['POST'])
@jwt_required()
def confirm_delete():
    usuario_id = get_jwt_identity()
    data = request.get_json()
    if not data or 'delete_request_id' not in data or 'password' not in data:
        print(f"Faltan datos en confirm_delete: {data}")
        return jsonify({"msg": "Se requiere delete_request_id y contraseña"}), 400

    delete_request_id = data.get('delete_request_id')
    password = data.get('password')
    usuario = db.session.get(Usuario, int(usuario_id))

    if not usuario or not usuario.check_password(password):
        print(f"Contraseña incorrecta para usuario_id: {usuario_id}")
        return jsonify({"msg": "Contraseña incorrecta"}), 401

    notificacion = Notificacion.query.filter_by(usuario_id=usuario_id, delete_request_id=delete_request_id).first()
    if not notificacion:
        print(f"Notificación no encontrada para delete_request_id: {delete_request_id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "Solicitud de eliminación no encontrada"}), 404

    try:
        print(f"Mensaje de notificación: {notificacion.mensaje}")
        id_str = notificacion.mensaje.split('(ID: ')[1].split(')')[0].strip()
        registro_id = int(id_str)
        print(f"ID de registro extraído: {registro_id}")
    except (ValueError, IndexError) as e:
        print(f"Error al extraer id del mensaje: {str(e)}")
        return jsonify({"msg": "Formato de mensaje de notificación inválido"}), 

    if 'glucosa' in notificacion.mensaje.lower():
        registro = db.session.get(Glucosa, registro_id)
        tipo = 'glucosa'
    elif 'presión arterial' in notificacion.mensaje.lower():
        registro = db.session.get(PresionArterial, registro_id)
        tipo = 'presión arterial'
    elif 'oxigenación' in notificacion.mensaje.lower():
        registro = db.session.get(Oxigenacion, registro_id)
        tipo = 'oxigenación'
    elif 'frecuencia cardíaca' in notificacion.mensaje.lower():
        registro = db.session.get(FrecuenciaCardiaca, registro_id)
        tipo = 'frecuencia cardíaca'
    elif 'medicamento' in notificacion.mensaje.lower():
        registro = db.session.get(Medicamento, registro_id)
        tipo = 'medicamento'
    else:
        print(f"Tipo de registro desconocido en mensaje: {notificacion.mensaje}")
        return jsonify({"msg": "Tipo de registro desconocido"}), 400

    if not registro:
        print(f"Registro de {tipo} no encontrado: id={registro_id}")
        return jsonify({"msg": f"Registro de {tipo} no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para {tipo} id: {registro_id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    try:
        db.session.delete(registro)
        db.session.delete(notificacion)
        db.session.commit()
        print(f"Registro de {tipo} id: {registro_id} y notificación delete_request_id: {delete_request_id} eliminados exitosamente")
        
        # Enviar notificación de eliminación exitosa
        notificacion_exitosa = Notificacion(
            usuario_id=usuario_id,
            mensaje='Registro eliminado correctamente',
            fecha=datetime.utcnow().date(),
            hora=datetime.utcnow().time(),
        )
        db.session.add(notificacion_exitosa)
        db.session.commit()
        enviar_notificacion_fcm(
            usuario_id,
            'WHS Medicine - Eliminación Exitosa',
            'Registro eliminado correctamente',
            None
        )
        
        return jsonify({"msg": "Registro eliminado"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al eliminar registro de {tipo}: {str(e)}")
        return jsonify({"msg": f"Error al eliminar registro: {str(e)}"}), 500

@app.route('/api/presiones_arteriales/<int:id>', methods=['DELETE'])
@jwt_required()
def eliminar_presion_arterial(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(PresionArterial, id)
    if not registro:
        print(f"Registro de presión arterial no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para presión arterial id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    delete_request_id = str(uuid.uuid4())
    mensaje = f'Confirma la eliminación del registro de presión arterial del {registro.fecha} a las {registro.hora.strftime("%H:%M")} (ID: {id})'
    
    notificacion = Notificacion(
        usuario_id=usuario_id,
        mensaje=mensaje,
        fecha=datetime.utcnow().date(),
        hora=datetime.utcnow().time(),
        delete_request_id=delete_request_id
    )
    db.session.add(notificacion)
    try:
        db.session.commit()
        print(f"Notificación creada con delete_request_id: {delete_request_id}, mensaje: {mensaje}")
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear notificación: {str(e)}")
        return jsonify({"msg": f"Error al crear notificación: {str(e)}"}), 500

    if enviar_notificacion_fcm(
        usuario_id,
        'WHS Medicine - Confirmar Eliminación',
        mensaje,
        delete_request_id
    ):
        return jsonify({"msg": "Solicitud de eliminación enviada. Confirma desde la notificación.", "delete_request_id": delete_request_id}), 200
    else:
        print(f"Error al enviar notificación FCM para usuario_id: {usuario_id}")
        return jsonify({"msg": "Error al enviar notificación"}), 500

@app.route('/api/oxigenaciones/<int:id>', methods=['DELETE'])
@jwt_required()
def eliminar_oxigenacion(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Oxigenacion, id)
    if not registro:
        print(f"Registro de oxigenación no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para oxigenación id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    delete_request_id = str(uuid.uuid4())
    mensaje = f'Confirma la eliminación del registro de oxigenación del {registro.fecha} a las {registro.hora.strftime("%H:%M")} (ID: {id})'
    
    notificacion = Notificacion(
        usuario_id=usuario_id,
        mensaje=mensaje,
        fecha=datetime.utcnow().date(),
        hora=datetime.utcnow().time(),
        delete_request_id=delete_request_id
    )
    db.session.add(notificacion)
    try:
        db.session.commit()
        print(f"Notificación creada con delete_request_id: {delete_request_id}, mensaje: {mensaje}")
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear notificación: {str(e)}")
        return jsonify({"msg": f"Error al crear notificación: {str(e)}"}), 500

    if enviar_notificacion_fcm(
        usuario_id,
        'WHS Medicine - Confirmar Eliminación',
        mensaje,
        delete_request_id
    ):
        return jsonify({"msg": "Solicitud de eliminación enviada. Confirma desde la notificación.", "delete_request_id": delete_request_id}), 200
    else:
        print(f"Error al enviar notificación FCM para usuario_id: {usuario_id}")
        return jsonify({"msg": "Error al enviar notificación"}), 500

@app.route('/api/frecuencias_cardiacas/<int:id>', methods=['DELETE'])
@jwt_required()
def eliminar_frecuencia_cardiaca(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(FrecuenciaCardiaca, id)
    if not registro:
        print(f"Registro de frecuencia cardíaca no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para frecuencia cardíaca id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    delete_request_id = str(uuid.uuid4())
    mensaje = f'Confirma la eliminación del registro de frecuencia cardíaca del {registro.fecha} a las {registro.hora.strftime("%H:%M")} (ID: {id})'
    
    notificacion = Notificacion(
        usuario_id=usuario_id,
        mensaje=mensaje,
        fecha=datetime.utcnow().date(),
        hora=datetime.utcnow().time(),
        delete_request_id=delete_request_id
    )
    db.session.add(notificacion)
    try:
        db.session.commit()
        print(f"Notificación creada con delete_request_id: {delete_request_id}, mensaje: {mensaje}")
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear notificación: {str(e)}")
        return jsonify({"msg": f"Error al crear notificación: {str(e)}"}), 500

    if enviar_notificacion_fcm(
        usuario_id,
        'WHS Medicine - Confirmar Eliminación',
        mensaje,
        delete_request_id
    ):
        return jsonify({"msg": "Solicitud de eliminación enviada. Confirma desde la notificación.", "delete_request_id": delete_request_id}), 200
    else:
        print(f"Error al enviar notificación FCM para usuario_id: {usuario_id}")
        return jsonify({"msg": "Error al enviar notificación"}), 500

@app.route('/api/medicamentos/<int:id>', methods=['DELETE'])
@jwt_required()
def eliminar_medicamento(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Medicamento, id)
    if not registro:
        print(f"Registro de medicamento no encontrado: id={id}")
        return jsonify({"msg": "Medicamento no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para medicamento id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    delete_request_id = str(uuid.uuid4())
    mensaje = f'Confirma la eliminación del registro de medicamento del {registro.fecha} a las {registro.hora_toma.strftime("%H:%M")} (ID: {id})'
    
    notificacion = Notificacion(
        usuario_id=usuario_id,
        mensaje=mensaje,
        fecha=datetime.utcnow().date(),
        hora=datetime.utcnow().time(),
        delete_request_id=delete_request_id
    )
    db.session.add(notificacion)
    try:
        db.session.commit()
        print(f"Notificación creada con delete_request_id: {delete_request_id}, mensaje: {mensaje}")
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear notificación: {str(e)}")
        return jsonify({"msg": f"Error al crear notificación: {str(e)}"}), 500

    if enviar_notificacion_fcm(
        usuario_id,
        'WHS Medicine - Confirmar Eliminación',
        mensaje,
        delete_request_id
    ):
        return jsonify({"msg": "Solicitud de eliminación enviada. Confirma desde la notificación.", "delete_request_id": delete_request_id}), 200
    else:
        print(f"Error al enviar notificación FCM para usuario_id: {usuario_id}")
        return jsonify({"msg": "Error al enviar notificación"}), 500

@app.route('/api/glucosas', methods=['GET'])
@jwt_required()
def obtener_glucosas():
    usuario_id = get_jwt_identity()
    fecha_str = request.args.get('fecha')

    query = Glucosa.query.filter_by(usuario_id=usuario_id)
    if fecha_str:
        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
            query = query.filter_by(fecha=fecha)
        except ValueError:
            print(f"Formato de fecha inválido: {fecha_str}")
            return jsonify({"msg": "Formato de fecha inválido"}), 400

    glucosas = query.order_by(Glucosa.fecha.desc(), Glucosa.hora.desc()).all()
    resultado = [{
        "id": g.id,
        "fecha": g.fecha.isoformat(),
        "hora": g.hora.strftime('%H:%M:%S'),
        "valor": float(g.valor),
        "fecha_creacion": g.fecha_creacion.isoformat()
    } for g in glucosas]
    print(f"Glucosas obtenidas para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200


@app.route('/api/medicamentos', methods=['GET'])
@jwt_required()
def obtener_medicamentos():
    usuario_id = get_jwt_identity()
    fecha_str = request.args.get('fecha')

    if not fecha_str:
        print("Fecha no proporcionada en obtener_medicamentos")
        return jsonify({"msg": "Fecha es requerida (YYYY-MM-DD)"}), 400

    try:
        fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
    except ValueError:
        print(f"Formato de fecha inválido: {fecha_str}")
        return jsonify({"msg": "Formato de fecha inválido"}), 400

    medicamentos = Medicamento.query.filter_by(usuario_id=usuario_id, fecha=fecha).all()
    resultado = [{
        "id": m.id,
        "nombre": m.nombre,
        "dosis": m.dosis,
        "hora_toma": m.hora_toma.strftime('%H:%M:%S'),
        "fecha": m.fecha.isoformat(),
        "sintomas": m.sintomas
    } for m in medicamentos]
    print(f"Medicamentos obtenidos para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200
@app.route('/api/glucosas/<int:id>', methods=['PUT'])
@jwt_required()
def actualizar_glucosa(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Glucosa, id)
    if not registro:
        print(f"Registro de glucosa no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para glucosa id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    data = request.get_json()
    if 'fecha' in data:
        try:
            registro.fecha = datetime.strptime(data['fecha'], '%Y-%m-%d').date()
        except ValueError:
            print(f"Formato de fecha inválido: {data['fecha']}")
            return jsonify({"msg": "Formato fecha inválido"}), 400
    if 'hora' in data:
        try:
            registro.hora = datetime.strptime(data['hora'], '%H:%M:%S').time()
        except ValueError:
            print(f"Formato de hora inválido: {data['hora']}")
            return jsonify({"msg": "Formato de hora inválido"}), 400
    if 'valor' in data:
        try:
            valor = float(data['valor'])
            if valor < 0 or valor > 999.99:
                print(f"Valor de glucosa fuera de rango: {valor}")
                return jsonify({"msg": "El valor de glucosa debe estar entre 0 y 999.99"}), 400
            registro.valor = valor
        except (ValueError, TypeError):
            print(f"Valor de glucosa inválido: {data['valor']}")
            return jsonify({"msg": "Valor de glucosa inválido"}), 400

    try:
        db.session.commit()
        print(f"Registro de glucosa actualizado: id={id}")
        return jsonify({"msg": "Registro de glucosa editado correctamente"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al actualizar glucosa: {str(e)}")
        return jsonify({"msg": f"Error al actualizar registro: {str(e)}"}), 500
    
@app.route('/api/presiones_arteriales/<int:id>', methods=['PUT'])
@jwt_required()
def actualizar_presion_arterial(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(PresionArterial, id)
    if not registro:
        print(f"Registro de presión arterial no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para presión arterial id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403
    data = request.get_json()
    if 'fecha' in data:
        try:
            registro.fecha = datetime.strptime(data['fecha'], '%Y-%m-%d').date()
        except ValueError:
            print(f"Formato de fecha inválido: {data['fecha']}")
            return jsonify({"msg": "Formato fecha inválido"}), 400
    if 'hora' in data:
        try:
            registro.hora = datetime.strptime(data['hora'], '%H:%M:%S').time()
        except ValueError:
            print(f"Formato de hora inválido: {data['hora']}")
            return jsonify({"msg": "Formato hora inválido"}), 400
    if 'sistolica' in data:
        try:
            registro.sistolica = int(data['sistolica'])
        except (ValueError, TypeError):
            print(f"Valor de presión sistólica inválido: {data['sistolica']}")
            return jsonify({"msg": "Valor de presión sistólica inválido"}), 400
    if 'diastolica' in data:
        try:
            registro.diastolica = int(data['diastolica'])
        except (ValueError, TypeError):
            print(f"Valor de presión diastólica inválido: {data['diastolica']}")
            return jsonify({"msg": "Valor de presión diastólica inválido"}), 400

    try:
        db.session.commit()
        print(f"Registro de presión arterial actualizado: id={id}")
        return jsonify({"msg": "Registro actualizado"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al actualizar presión arterial: {str(e)}")
        return jsonify({"msg": f"Error al actualizar registro: {str(e)}"}), 500

@app.route('/api/oxigenaciones/<int:id>', methods=['PUT'])
@jwt_required()
def actualizar_oxigenacion(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Oxigenacion, id)
    if not registro:
        print(f"Registro de oxigenación no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para oxigenación id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403
    data = request.get_json()
    if 'fecha' in data:
        try:
            registro.fecha = datetime.strptime(data['fecha'], '%Y-%m-%d').date()
        except ValueError:
            print(f"Formato de fecha inválido: {data['fecha']}")
            return jsonify({"msg": "Formato fecha inválido"}), 400
    if 'hora' in data:
        try:
            registro.hora = datetime.strptime(data['hora'], '%H:%M:%S').time()
        except ValueError:
            print(f"Formato de hora inválido: {data['hora']}")
            return jsonify({"msg": "Formato hora inválido"}), 400
    if 'valor' in data:
        try:
            valor = int(data['valor'])
            if valor < 0 or valor > 100:
                print(f"Valor de oxigenación fuera de rango: {valor}")
                return jsonify({"msg": "El valor de oxigenación debe estar entre 0 y 100"}), 400
            registro.valor = valor
        except (ValueError, TypeError):
            print(f"Valor de oxigenación inválido: {data['valor']}")
            return jsonify({"msg": "Valor de oxigenación inválido"}), 400

    try:
        db.session.commit()
        print(f"Registro de oxigenación actualizado: id={id}")
        return jsonify({"msg": "Registro actualizado"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al actualizar oxigenación: {str(e)}")
        return jsonify({"msg": f"Error al actualizar registro: {str(e)}"}), 500

@app.route('/api/frecuencias_cardiacas/<int:id>', methods=['PUT'])
@jwt_required()
def actualizar_frecuencia_cardiaca(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(FrecuenciaCardiaca, id)
    if not registro:
        print(f"Registro de frecuencia cardíaca no encontrado: id={id}")
        return jsonify({"msg": "Registro no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para frecuencia cardíaca id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    data = request.get_json()
    if 'fecha' in data:
        try:
            registro.fecha = datetime.strptime(data['fecha'], '%Y-%m-%d').date()
        except ValueError:
            print(f"Formato de fecha inválido: {data['fecha']}")
            return jsonify({"msg": "Formato fecha inválido"}), 400
    if 'hora' in data:
        try:
            registro.hora = datetime.strptime(data['hora'], '%H:%M:%S').time()
        except ValueError:
            print(f"Formato de hora inválido: {data['hora']}")
            return jsonify({"msg": "Formato hora inválido"}), 400
    if 'valor' in data:
        try:
            valor = int(data['valor'])
            if valor < 0 or valor > 300:
                print(f"Valor de frecuencia cardíaca fuera de rango: {valor}")
                return jsonify({"msg": "El valor de frecuencia cardíaca debe estar entre 0 y 300"}), 400
            registro.valor = valor
        except (ValueError, TypeError):
            print(f"Valor de frecuencia cardíaca inválido: {data['valor']}")
            return jsonify({"msg": "Valor de frecuencia cardíaca inválido"}), 400

    try:
        db.session.commit()
        print(f"Registro de frecuencia cardíaca actualizado: id={id}")
        return jsonify({"msg": "Registro actualizado"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al actualizar frecuencia cardíaca: {str(e)}")
        return jsonify({"msg": f"Error al actualizar registro: {str(e)}"}), 500

@app.route('/api/medicamentos', methods=['POST'])
@jwt_required()
def crear_medicamento():
    usuario_id = get_jwt_identity()
    data = request.get_json()

    nombre = data.get('nombre')
    dosis = data.get('dosis')
    hora_toma_str = data.get('hora_toma')
    fecha_str = data.get('fecha')
    sintomas = data.get('sintomas')

    if not nombre or not dosis or not hora_toma_str or not fecha_str:
        print(f"Faltan datos obligatorios en crear_medicamento: {data}")
        return jsonify({"msg": "Faltan datos obligatorios"}), 400

    try:
        hora_toma = datetime.strptime(hora_toma_str, '%H:%M:%S').time()
        fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
    except ValueError:
        print(f"Formato de hora o fecha inválido: hora_toma={hora_toma_str}, fecha={fecha_str}")
        return jsonify({"msg": "Formato de hora o fecha inválido"}), 400

    medicamento = Medicamento(
        usuario_id=usuario_id,
        nombre=nombre,
        dosis=dosis,
        hora_toma=hora_toma,
        fecha=fecha,
        sintomas=sintomas
    )

    try:
        db.session.add(medicamento)
        db.session.commit()
        print(f"Medicamento creado para usuario_id: {usuario_id}, id: {medicamento.id}")
        return jsonify({"msg": "Medicamento creado", "id": medicamento.id}), 201
    except Exception as e:
        db.session.rollback()
        print(f"Error al crear medicamento: {str(e)}")
        return jsonify({"msg": f"Error al crear medicamento: {str(e)}"}), 500

@app.route('/api/medicamentos/<int:id>', methods=['PUT'])
@jwt_required()
def actualizar_medicamento(id):
    usuario_id = get_jwt_identity()
    registro = db.session.get(Medicamento, id)
    if not registro:
        print(f"Registro de medicamento no encontrado: id={id}")
        return jsonify({"msg": "Medicamento no encontrado"}), 404
    if registro.usuario_id != int(usuario_id):
        print(f"Usuario no autorizado para medicamento id: {id}, usuario_id: {usuario_id}")
        return jsonify({"msg": "No autorizado"}), 403

    data = request.get_json()
    if 'nombre' in data:
        registro.nombre = data['nombre']
    if 'dosis' in data:
        registro.dosis = data['dosis']
    if 'hora_toma' in data:
        try:
            registro.hora_toma = datetime.strptime(data['hora_toma'], '%H:%M:%S').time()
        except ValueError:
            print(f"Formato de hora inválido: {data['hora_toma']}")
            return jsonify({"msg": "Formato hora inválido"}), 400
    if 'fecha' in data:
        try:
            registro.fecha = datetime.strptime(data['fecha'], '%Y-%m-%d').date()
        except ValueError:
            print(f"Formato de fecha inválido: {data['fecha']}")
            return jsonify({"msg": "Formato fecha inválido"}), 400
    if 'sintomas' in data:
        registro.sintomas = data['sintomas']

    try:
        db.session.commit()
        print(f"Medicamento actualizado: id={id}")
        return jsonify({"msg": "Medicamento actualizado"}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error al actualizar medicamento: {str(e)}")
        return jsonify({"msg": f"Error al actualizar medicamento: {str(e)}"}), 500

@app.route('/api/smartwatch/<int:usuario_id>', methods=['GET'])
def datos_smartwatch(usuario_id):
    glucosa = Glucosa.query.filter_by(usuario_id=usuario_id).order_by(Glucosa.fecha.desc(), Glucosa.hora.desc()).first()
    presion = PresionArterial.query.filter_by(usuario_id=usuario_id).order_by(PresionArterial.fecha.desc(), PresionArterial.hora.desc()).first()
    oxigenacion = Oxigenacion.query.filter_by(usuario_id=usuario_id).order_by(Oxigenacion.fecha.desc(), Oxigenacion.hora.desc()).first()
    frecuencia = FrecuenciaCardiaca.query.filter_by(usuario_id=usuario_id).order_by(FrecuenciaCardiaca.fecha.desc(), FrecuenciaCardiaca.hora.desc()).first()

    if not any([glucosa, presion, oxigenacion, frecuencia]):
        print(f"No hay registros para usuario_id: {usuario_id}")
        return jsonify({"msg": "No hay registros para este usuario"}), 404

    response = {
        "presion_arterial": f"{presion.sistolica}/{presion.diastolica} mmHg" if presion else "N/A",
        "oxigenacion": f"{oxigenacion.valor}%" if oxigenacion else "N/A",
        "glucosa": f"{glucosa.valor} mg/dL" if glucosa else "N/A",
        "frecuencia_cardiaca": f"{frecuencia.valor} bpm" if frecuencia else "N/A"
    }
    print(f"Datos de smartwatch obtenidos para usuario_id: {usuario_id}")
    return jsonify(response), 200

@app.route('/api/tv/salud/<int:usuario_id>', methods=['GET'])
def datos_tv_salud(usuario_id):
    glucosa = Glucosa.query.filter_by(usuario_id=usuario_id).order_by(Glucosa.fecha.desc(), Glucosa.hora.desc()).first()
    presion = PresionArterial.query.filter_by(usuario_id=usuario_id).order_by(PresionArterial.fecha.desc(), PresionArterial.hora.desc()).first()
    oxigenacion = Oxigenacion.query.filter_by(usuario_id=usuario_id).order_by(Oxigenacion.fecha.desc(), Oxigenacion.hora.desc()).first()
    frecuencia = FrecuenciaCardiaca.query.filter_by(usuario_id=usuario_id).order_by(FrecuenciaCardiaca.fecha.desc(), FrecuenciaCardiaca.hora.desc()).first()

    if not any([glucosa, presion, oxigenacion, frecuencia]):
        print(f"No hay registros para usuario_id: {usuario_id}")
        return jsonify({"msg": "No hay registros para este usuario"}), 404

    response = {
        "presion_arterial": f"{presion.sistolica}/{presion.diastolica} mmHg" if presion else "N/A",
        "oxigenacion": f"{oxigenacion.valor}%" if oxigenacion else "N/A",
        "glucosa": f"{glucosa.valor} mg/dL" if glucosa else "N/A",
        "frecuencia_cardiaca": f"{frecuencia.valor} bpm" if frecuencia else "N/A"
    }
    print(f"Datos de TV salud obtenidos para usuario_id: {usuario_id}")
    return jsonify(response), 200
@app.route('/api/logout', methods=['POST'])
@jwt_required()
def logout():
    usuario_id = get_jwt_identity()
    data = request.get_json(force=True)
    fcm_token = data.get('fcm_token')

    if not fcm_token:
        print(f"Error: No se proporcionó FCM token para usuario_id: {usuario_id}")
        return jsonify({"msg": "FCM token es requerido"}), 400

    try:
        token_entry = FcmToken.query.filter_by(usuario_id=usuario_id, token=fcm_token).first()
        if token_entry:
            db.session.delete(token_entry)
            db.session.commit()
            print(f"Token FCM eliminado para usuario_id: {usuario_id}, token: {fcm_token}")
            return jsonify({"msg": "Sesión cerrada y token FCM eliminado"}), 200
        else:
            print(f"Token FCM no encontrado para usuario_id: {usuario_id}, token: {fcm_token}")
            return jsonify({"msg": "Token FCM no encontrado"}), 404
    except Exception as e:
        db.session.rollback()
        print(f"Error al cerrar sesión: {str(e)}")
        return jsonify({"msg": f"Error al cerrar sesión: {str(e)}"}), 500
@app.route('/api/salud/normales', methods=['GET'])
def valores_normales():
    info = {
        "Presion Arterial": "120/80 mmHg (normal)",
        "Oxigenacion": "95% - 100%",
        "Glucosa": "70 - 110 mg/dL (en ayunas)",
        "Frecuencia Cardiaca": "60 - 100 latidos por minuto"
    }
    print("Valores normales de salud devueltos")
    return jsonify(info), 200
@app.route('/api/frecuencias_cardiacas', methods=['GET'])
@jwt_required()
def obtener_frecuencias_cardiacas():
    usuario_id = get_jwt_identity()
    fecha_str = request.args.get('fecha')

    query = FrecuenciaCardiaca.query.filter_by(usuario_id=usuario_id)
    if fecha_str:
        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
            query = query.filter_by(fecha=fecha)
        except ValueError:
            print(f"Formato de fecha inválido: {fecha_str}")
            return jsonify({"msg": "Formato de fecha inválido"}), 400

    frecuencias = query.order_by(FrecuenciaCardiaca.fecha.desc(), FrecuenciaCardiaca.hora.desc()).all()
    resultado = [{
        "id": f.id,
        "fecha": f.fecha.isoformat(),
        "hora": f.hora.strftime('%H:%M:%S'),
        "valor": int(f.valor),
        "fecha_creacion": f.fecha_creacion.isoformat()
    } for f in frecuencias]
    print(f"Frecuencias cardíacas obtenidas para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200
@app.route('/api/presiones_arteriales', methods=['GET'])
@jwt_required()
def obtener_presiones_arteriales():
    usuario_id = get_jwt_identity()
    fecha_str = request.args.get('fecha')

    query = PresionArterial.query.filter_by(usuario_id=usuario_id)
    if fecha_str:
        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
            query = query.filter_by(fecha=fecha)
        except ValueError:
            print(f"Formato de fecha inválido: {fecha_str}")
            return jsonify({"msg": "Formato de fecha inválido"}), 400

    presiones = query.order_by(PresionArterial.fecha.desc(), PresionArterial.hora.desc()).all()
    resultado = [{
        "id": p.id,
        "fecha": p.fecha.isoformat(),
        "hora": p.hora.strftime('%H:%M:%S'),
        "sistolica": int(p.sistolica),
        "diastolica": int(p.diastolica),
        "fecha_creacion": p.fecha_creacion.isoformat()
    } for p in presiones]
    print(f"Presiones arteriales obtenidas para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200

@app.route('/api/oxigenaciones', methods=['GET'])
@jwt_required()
def obtener_oxigenaciones():
    usuario_id = get_jwt_identity()
    fecha_str = request.args.get('fecha')

    query = Oxigenacion.query.filter_by(usuario_id=usuario_id)
    if fecha_str:
        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
            query = query.filter_by(fecha=fecha)
        except ValueError:
            print(f"Formato de fecha inválido: {fecha_str}")
            return jsonify({"msg": "Formato de fecha inválido"}), 400

    oxigenaciones = query.order_by(Oxigenacion.fecha.desc(), Oxigenacion.hora.desc()).all()
    resultado = [{
        "id": o.id,
        "fecha": o.fecha.isoformat(),
        "hora": o.hora.strftime('%H:%M:%S'),
        "valor": int(o.valor),
        "fecha_creacion": o.fecha_creacion.isoformat()
    } for o in oxigenaciones]
    print(f"Oxigenaciones obtenidas para usuario_id: {usuario_id}, total: {len(resultado)}")
    return jsonify(resultado), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
app.run(debug=True)