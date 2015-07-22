from setuptools import setup
from setuptools.extension import Extension
from Cython.Distutils import build_ext
from os.path import join
import functools

import os

rel = functools.partial(join, os.getcwd())

ext_modules = [
    Extension(
        "_pydmc",
        extra_compile_args=['-std=gnu99', '-O2', '-D_LARGEFILE64_SOURCE'],
        sources=["src/_pydmc.pyx",
                 'src/MurmurHash3.c'],

        include_dirs=[rel('src')],
        library_dirs=[rel('src')]
    )
]

setup(
    name='Python DMC',
    version='0.1',
    author='Jake Heinz',
    author_email='me@jh.gg',
    url="http://github.com/jhgg/pydmc",
    description='A high performance python direct-memory-cache type thing.',
    license='MIT License',
    cmdclass={'build_ext': build_ext},
    zip_safe=False,
    package_dir={'': 'src'},
    py_modules=['pydmc'],
    ext_modules=ext_modules,
    test_suite='nose.collector'
)
