with open('face_cnn.sod', 'rb') as f:
    data = f.read()

with open('model_data.h', 'w') as f:
    f.write('#ifndef MODEL_DATA_H\n')
    f.write('#define MODEL_DATA_H\n\n')
    f.write('const unsigned char model_data[] = {')
    f.write(','.join(hex(b) for b in data))
    f.write('};\n\n')
    f.write('#endif // MODEL_DATA_H\n')
